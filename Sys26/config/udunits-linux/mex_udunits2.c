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

/* -------------------------------------------------------------
 * Suppress / restore stderr (cross-platform)
 * ------------------------------------------------------------- */
void suppress_stderr_start(int *old_fd)
{
#if defined(_WIN32)
    *old_fd = _dup(_fileno(stderr));
    int dev_null = _open(DEVNULL, _O_WRONLY);
    _dup2(dev_null, _fileno(stderr));
    _close(dev_null);
#else
    *old_fd = dup(fileno(stderr));
    int dev_null = open(DEVNULL, O_WRONLY);
    dup2(dev_null, fileno(stderr));
    close(dev_null);
#endif
}

void suppress_stderr_end(int old_fd)
{
#if defined(_WIN32)
    _dup2(old_fd, _fileno(stderr));
    _close(old_fd);
#else
    dup2(old_fd, fileno(stderr));
    close(old_fd);
#endif
}

/* -------------------------------------------------------------
 * MEX entry point
 * ------------------------------------------------------------- */
void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    if (nrhs < 4) {
        mexErrMsgIdAndTxt(
            "mex_udunits2:inputError",
            "Expected 4 inputs: y = mex_udunits2(x, fromUnit, toUnit, xml_path)");
    }

    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgTxt("First input must be real double values");
    }

    if (!mxIsChar(prhs[1]) || !mxIsChar(prhs[2]) || !mxIsChar(prhs[3])) {
        mexErrMsgTxt("Second, third, and fourth inputs must be strings");
    }

    char *fromStr  = mxArrayToString(prhs[1]);
    char *toStr    = mxArrayToString(prhs[2]);
    char *xml_path = mxArrayToString(prhs[3]);

    if (!fromStr || !toStr || !xml_path) {
        mexErrMsgTxt("Failed to parse input strings.");
    }

    /* =========================================================
     * SUPPRESS STDERR FOR *ALL* UDUNITS OPERATIONS
     * ========================================================= */
    int old_stderr;
    suppress_stderr_start(&old_stderr);

    ut_system *sys = ut_read_xml(xml_path);
    if (!sys) {
        suppress_stderr_end(old_stderr);
        mxFree(fromStr);
        mxFree(toStr);
        mxFree(xml_path);
        mexErrMsgTxt("❌ Failed to initialize UDUNITS2. Check udunits2.xml path.");
    }

    ut_unit *fromUnit = ut_parse(sys, fromStr, UT_UTF8);
    ut_unit *toUnit   = ut_parse(sys, toStr,   UT_UTF8);

    cv_converter *conv = NULL;
    if (fromUnit && toUnit) {
        conv = ut_get_converter(fromUnit, toUnit);
    }

    suppress_stderr_end(old_stderr);
    /* ========================================================= */

    mxFree(fromStr);
    mxFree(toStr);
    mxFree(xml_path);

    if (!fromUnit || !toUnit || !conv) {
        if (fromUnit) ut_free(fromUnit);
        if (toUnit)   ut_free(toUnit);
        ut_free_system(sys);

        mexPrintf("❌ Units not convertible or failed to parse. Returning NaN.\n");
        plhs[0] = mxCreateDoubleScalar(mxGetNaN());
        return;
    }

    /* Create output array */
    const mwSize *dims = mxGetDimensions(prhs[0]);
    mxArray *out = mxCreateNumericArray(
        mxGetNumberOfDimensions(prhs[0]),
        dims,
        mxDOUBLE_CLASS,
        mxREAL);

    double *x = mxGetPr(prhs[0]);
    double *y = mxGetPr(out);
    mwSize n  = mxGetNumberOfElements(prhs[0]);

    for (mwSize i = 0; i < n; ++i) {
        y[i] = cv_convert_double(conv, x[i]);
    }

    plhs[0] = out;

    /* Cleanup */
    cv_free(conv);
    ut_free(fromUnit);
    ut_free(toUnit);
    ut_free_system(sys);
}

