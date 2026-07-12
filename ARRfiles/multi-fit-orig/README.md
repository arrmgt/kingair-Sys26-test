# NetCDF Multivariate Correction App

MATLAB tool for fitting parameters that force `X = Y`, given 4-5 input
measurements, over large collections of NetCDF files (gigabytes, out of
core — the full dataset is never loaded into memory at once).

## Working assumption (please confirm)

"Force X=Y" is treated as a **calibration/correction problem**:

```
response  = Y - X                    (the correction needed)
model:      response ~ f(predictors)
so that:    X_corrected = X + f(predictors)  ≈  Y
```

The app regresses the gap between X and Y on your 4-5 measurement
variables, then that fitted function can be applied going forward to
correct new X readings toward Y. If you actually want to predict Y
directly from the predictors (ordinary regression, ignoring X), that's a
one-line change — see the comment in `computeResponse` inside
`streamFitCorrection.m`. If "force X=Y" instead meant solving a hard
constraint per-sample (not a statistical fit), that's a different
problem (per-row equation solving / root-finding) — let me know and this
gets rebuilt around that instead.

## Files

| File | Purpose |
|---|---|
| `ncRegressionApp.m` | GUI app. Run `app = ncRegressionApp` to launch. |
| `streamFitCorrection.m` | Core out-of-core regression engine (no GUI needed). |
| `buildDesignMatrix.m` | Expands raw predictors into linear/interaction/quadratic terms. |
| `readNetCDFChunk.m` | Reads + flattens variables from one .nc file, converts fill values to NaN. |
| `listNetCDFVariables.m` | Lists variables/dimensions in a .nc file (for exploring an unfamiliar dataset). |
| `applyCorrectionModel.m` | Applies a fitted model to new predictor/X data. |
| `exportModel.m` | Saves a fitted model to `.mat` + a coefficients `.csv`. |
| `example_run.m` | Headless / command-line / batch-job example, no GUI. |

## How it scales to gigabytes

Ordinary least squares only needs a few small sufficient statistics:
`X'X`, `X'y`, `y'y`, `sum(y)`, `n` (each `p x p` or smaller, p = number of
model terms, typically well under 30). `streamFitCorrection.m` processes
your NetCDF files **one at a time**, accumulates those statistics, and
solves the normal equations only once at the end. R² and RMSE are also
derived from the same accumulated sums — no second pass over the raw
data is needed (except when `standardize=true`, which uses one extra
pass to get predictor mean/std before the fitting pass).

**Current limitation:** each individual file's requested variables are
read fully into memory (one file at a time) via `ncread`. This is fine
as long as no single file exceeds available RAM, even though the full
collection is gigabytes. If any single file is itself too large to fit
in memory, tell me the typical file size/shape and this can be switched
to indexed block reads (`ncread` with `start`/`count`).

**Assumption on file layout:** within each file, the predictor, X, and Y
variables are assumed to be co-located on the same grid (same number of
elements after flattening). If your variables have different dimensions
per-file (e.g. X on one grid, predictors on another), they need to be
regridded/interpolated onto a common grid before running this — that's a
separate preprocessing step I can help build once I know your file
structure (run `listNetCDFVariables` on a sample file and share the
output).

## Quick start (GUI)

```matlab
app = ncRegressionApp;
```

1. "Select NetCDF Folder..." — recursively scans for `*.nc`
2. Pick your 4-5 predictor variables, and the X / Y variables
3. Choose model order (linear / interactions / quadratic) and whether to
   standardize predictors
4. "Run Fit" — runs on a background worker if Parallel Computing Toolbox
   is available (UI stays responsive); otherwise runs synchronously
5. Review coefficients, R²/RMSE (train + held-out validation files), and
   the diagnostic scatter plot
6. "Export Model..." to save

## Quick start (headless / batch)

Edit and run `example_run.m` — same underlying functions, no GUI, better
suited to a cluster or very long unattended runs.

## Requirements

- MATLAB R2019b or newer (uses `uifigure`/App Designer-style components;
  `scroll()` on `uitextarea` wants R2021a+ — on older releases just
  delete that one line, it's cosmetic)
- Parallel Computing Toolbox optional (used for a responsive GUI during
  long fits; not required for correctness)

## Next steps / things to tell me so I can tighten this up

- Your actual NetCDF variable names for the 4-5 predictors, X, and Y
- Typical size of a single `.nc` file (vs. total dataset size)
- Whether "force X=Y" is calibration (current assumption), direct
  regression, or a per-sample constraint solve
- Whether you want nonlinear/ML models (e.g. regression trees, Gaussian
  process regression) instead of/alongside linear — MATLAB's
  Statistics and Machine Learning Toolbox has out-of-core-friendly
  options (e.g. `fitrtree`, incremental learning models) that can slot
  into the same file-streaming loop
