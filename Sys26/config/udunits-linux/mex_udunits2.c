#include "mex.h"
#include "udunits2.h"
#include <stdlib.h>
#include <stdio.h>

#if defined(_WIN32)
  #include <io.h>
  #include <fcntl.h>
  #define DEVNULL "NUL"
#else
  #include <unistd.h>
  #include <fcntl.h>
  #define DEVNULL "/dev/null"
#endif

/* ── persistent unit system ─────────────────────────────────────────────── */
static ut_system *cached_sys  = NULL;
static char      *cached_path = NULL;   /* track which XML was loaded */

static void cleanup(void) {
    if (cached_sys) { ut_free_system(cached_sys); cached_sys  = NULL; }
    if (cached_path){ free(cached_path);           cached_path = NULL; }
}

/* ── stderr suppression ──────────────────────────────────────────────────── */
static void suppress_stderr_start(int *old_fd) {
#if defined(_WIN32)
    *old_fd = _dup(_fileno(stderr));
    int dn  = _open(DEVNULL, _O_WRONLY);
    _dup2(dn, _fileno(stderr));
    _close(dn);
#else
    *old_fd = dup(fileno(stderr));
    int dn  = open(DEVNULL, O_WRONLY);
    dup2(dn, fileno(stderr));
    close(dn);
#endif
}

static void suppress_stderr_end(int old_fd) {
#if defined(_WIN32)
    _dup2(old_fd, _fileno(stderr));
    _close(old_fd);
#else
    dup2(old_fd, fileno(stderr));
    close(old_fd);
#endif
}

/* ── MEX entry point ─────────────────────────────────────────────────────── */
void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    /* ── argument checks ── */
    if (nrhs < 4)
        mexErrMsgIdAndTxt("mex_udunits2:inputError",
            "Expected 4 inputs: y = mex_udunits2(x, fromUnit, toUnit, xml_path)");

    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0]))
        mexErrMsgTxt("First input must be real double values");

    if (!mxIsChar(prhs[1]) || !mxIsChar(prhs[2]) || !mxIsChar(prhs[3]))
        mexErrMsgTxt("Second, third, and fourth inputs must be strings");

    char *fromStr  = mxArrayToString(prhs[1]);
    char *toStr    = mxArrayToString(prhs[2]);
    char *xml_path = mxArrayToString(prhs[3]);

    if (!fromStr || !toStr || !xml_path)
        mexErrMsgTxt("Failed to parse input strings.");

    /* ── load unit system once; reuse if same XML path ── */
    if (cached_sys == NULL || cached_path == NULL ||
        strcmp(cached_path, xml_path) != 0)
    {
        cleanup();                          /* free any previous system   */

        int old_stderr;
        suppress_stderr_start(&old_stderr);
        cached_sys = ut_read_xml(xml_path); /* warnings suppressed here   */
        suppress_stderr_end(old_stderr);

        if (!cached_sys) {
            mxFree(fromStr); mxFree(toStr); mxFree(xml_path);
            mexErrMsgTxt("Failed to initialize UDUNITS2. Check udunits2.xml path.");
        }

        cached_path = strdup(xml_path);     /* remember which path loaded */
        mexAtExit(cleanup);                 /* free on mex clear / exit   */
    }

    mxFree(xml_path);                       /* no longer needed           */

    /* ── parse units ── */
    ut_unit *fromUnit = ut_parse(cached_sys, fromStr, UT_UTF8);
    ut_unit *toUnit   = ut_parse(cached_sys, toStr,   UT_UTF8);
    mxFree(fromStr);
    mxFree(toStr);

    if (!fromUnit || !toUnit) {
        ut_free(fromUnit); ut_free(toUnit);
        mexPrintf("Failed to parse units. Returning NaN.\n");
        plhs[0] = mxCreateDoubleScalar(mxGetNaN());
        return;
    }

    /* ── build converter ── */
    cv_converter *conv = ut_get_converter(fromUnit, toUnit);
    if (!conv) {
        ut_free(fromUnit); ut_free(toUnit);
        mexPrintf("Units not convertible. Returning NaN.\n");
        plhs[0] = mxCreateDoubleScalar(mxGetNaN());
        return;
    }

    /* ── convert ── */
    const mwSize *dims = mxGetDimensions(prhs[0]);
    mxArray *out = mxCreateNumericArray(mxGetNumberOfDimensions(prhs[0]),
                                        dims, mxDOUBLE_CLASS, mxREAL);
    double *x = mxGetPr(prhs[0]);
    double *y = mxGetPr(out);
    mwSize  n = mxGetNumberOfElements(prhs[0]);

    for (mwSize i = 0; i < n; ++i)
        y[i] = cv_convert_double(conv, x[i]);

    plhs[0] = out;

    cv_free(conv);
    ut_free(fromUnit);
    ut_free(toUnit);
    /* ── do NOT free cached_sys here ── */
}

