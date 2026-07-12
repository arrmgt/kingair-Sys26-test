## UPDATE: pitot-static "f-factor" calibration pipeline (fcalc / lsqnonlin)

You provided your actual objective function (`fcalc`, used with
`lsqnonlin`), which is a **nonlinear** calibration fit -- your real
"force X=Y" problem is pitot-static position-error / f-factor
calibration, not the generic linear correction app described below.
That linear app (`ncRegressionApp.m`, `streamFitCorrection.m`, etc.)
still exists and works standalone, but it is NOT what solves your
`fcalc` problem. The new files for that are:

| File | Purpose |
|---|---|
| `fcalc.m` | Your residual function, transcribed as-pasted with one apparent copy/paste duplicate line removed (see comment at top of the file) -- **please diff against your original and confirm.** Depends on `tanAlpha`, `tanBeta`, `impactPcalc`, `fqCalc`, `mach`, `r858_solve3` already being on your MATLAB path; none of those were provided, so they are not included here. |
| `decimateNetCDFToCalPoints.m` | Reduces gigabytes of raw NetCDF data to a small table of calibration points (windowed mean + std), since `lsqnonlin` needs the full residual vector in memory each iteration and can't stream like the OLS engine below. Per your choice, this decimate-then-fit approach was used rather than a streaming Gauss-Newton solver. |
| `buildZStruct.m` | Maps the decimated table's columns onto the `Z` struct fields `fcalc` expects (DPA, DPB, DPR, DPN, DP1, PSA, mr, PTB) and builds `sigma`. |
| `runCalibrationFit.m` | Calls `lsqnonlin(@(x) fcalc(x,Z,sigma), x0, ...)`, returns fitted `betaf` plus diagnostics (approximate parameter standard errors from the Jacobian, before/after residual RMS). |
| `example_calibration_run.m` | End-to-end script using windowed decimation (mean/std per time or sample-count window) to shrink gigabytes down to calibration points. **Has a CONFIG section at the top you must edit.** |
| `loadFlightData.m` | Your actual starting point: load ONE NetCDF file, subset to your own in-flight index vector `kk`, run an outlier/sanity check (robust MAD test by default, plus optional physical bounds per variable) on top. No windowing -- every surviving in-flight sample becomes a calibration point. |
| `assembleMultiFlightData.m` | Same as `loadFlightData` but for a list of `{file, kk}` flights, concatenated into one dataset (tagged with a `FlightIndex` field for traceability) -- the natural next step once you have more than one flight. |
| `buildZFromStruct.m` | Like `buildZStruct.m` but for the struct-of-vectors that `loadFlightData`/`assembleMultiFlightData` produce (no `_mean` suffix, since nothing was windowed). |
| `example_calibration_run_single_flight.m` | Single-**NetCDF**-file, `kk`-index workflow: load → sanity check → fit → plot, with a commented-out block at the bottom showing the one-line change to go from one flight to many via `assembleMultiFlightData`. |
| `loadFlightDataFromMat.m` | **Matches your actual data source**: reads channels from a processed `.mat` file with `RAW`/`RATE` structs (each channel possibly at its own native rate), resamples every channel to a common `orate` via `changeRate(RAW.(name), RATE.(name), orate)`. Supports the manual script's TWO-STAGE kk: `opts.repairKkFcn` (a rough condition that drives `repairOne` -- gap-fills/extrapolates every channel, full length) followed by `opts.kkFcn` (a separate, final condition evaluated on the now-repaired data, used for the actual point selection). |
| `repairOne.m` | Ported from the manual script: interpolates a channel over gaps using known-good samples at a rough `kk`, and constant-extrapolates before/after that `kk`'s range -- WITHOUT shrinking the array. This runs before the final `kk` selection. |
| `example_calibration_run_matfile.m` | **Start here** -- wired to your real file/channels/two-stage kk/sigma. |
| `detectOutliers.m` | The outlier test `loadFlightData` uses per variable (MAD-based by default). |
| `addDummyZFields.m` | Fills in `Z` fields not yet available from data with a constant placeholder (currently used for `mr` -- see below). |
| `predictQConfidence.m` | Standard error and CONFIDENCE interval on `qx1` (the corrected impact pressure) via the delta method: propagates `runCalibrationFit`'s parameter covariance (`diagnostics.covB`) through `qx1` using a numerical Jacobian (`qx1` depends on `betaf` through `fcalc`'s iterative loop, no closed form). Reflects uncertainty in the fitted curve only. |
| `predictQTotalUncertainty.m` | Extends the above into a PREDICTION interval: adds the residual scatter propagated from each input channel's own measurement sigma (`sigma.PTB`, `.PSA`, `.DP1`, `.DPA`, `.DPB`, `.DPR`, `.DPN`) through `qx1` (another numerical Jacobian, this time w.r.t. the raw pressures), as an independent variance term. Returns a `breakdown` struct showing which channel's uncertainty dominates. |

### Unavailable channels (currently: mr)

Mixing ratio (`mr`) isn't available yet. Both example scripts now:
1. Leave `mr` out of `rawVarMap`, so it's never looked up in the NetCDF
   file (avoids `readNetCDFChunk` failing/skipping files over a missing
   variable).
2. Set `dummyZFields.mr = 0` and call `Z = addDummyZFields(Z, dummyZFields)`
   right after `buildZStruct`/`buildZFromStruct`, giving `Z.mr` a vector
   of zeros the same length as the other Z fields (i.e. zero over
   whatever range `kk` selected).

When real `mr` data becomes available: remove the `dummyZFields.mr` line,
add `'mr','mr'` (or your actual variable name) back to `rawVarMap`, and
drop the `addDummyZFields` call.

### Rate change (1000 Hz -> 25 Hz)

`lsqnonlin` needs the full residual vector in memory each iteration, and
raw data at 1000 Hz over a whole in-flight segment makes that painfully
slow (each iteration needs ~5 evaluations of `fcalc`/`r858_solve3` for
the finite-difference Jacobian over 4 parameters, each evaluation
touching every point). `loadFlightData.m` now downsamples the WHOLE raw
file with your `changeRate(X, irate, orate)` function, set via
`loadOpts.irate` / `loadOpts.orate` (see `example_calibration_run_single_flight.m`,
currently 1000 -> 25). This happens FIRST, before `kk` is applied --
**`kk` must be defined in the resampled (25 Hz) sample space**, not the
original 1000 Hz record. `assembleMultiFlightData.m` picks this up
automatically since it passes `opts` straight through to `loadFlightData`
for each flight (so every flight's `kk` must likewise be in its own
resampled sample space).

`changeRate` is assumed to already exist on your MATLAB path, same as
`tanAlpha`/`mach`/`r858_solve3`. If its signature differs from
`changeRate(X, irate, orate)`, set `loadOpts.changeRateFcn` to a
function handle wrapping it appropriately.

### If lsqnonlin stalls (flat resnorm, huge first-order optimality, ~0 step)

This pattern -- resnorm stops changing, step size collapses toward zero,
but first-order optimality stays enormous -- means the optimizer can't
trust its own gradient estimate. The likely cause in this specific model:
`f0 = XXf*betaf` inside `fcalc` is used as `fqx./f0`; if `f0` gets close
to zero anywhere in `Z` (at `x0`, or at one of the tiny per-parameter
perturbations `lsqnonlin` uses to estimate the Jacobian by finite
differences), that division blows up, and `fcalc`'s
`f = fillmissing(f,'constant',0)` line silently turns the resulting
Inf/NaN into a *fake perfect residual* (0) rather than flagging it --
which can hand the optimizer a wildly inconsistent, discontinuous
gradient estimate.

New tools for this:
- `checkFcalcConditioning(x0, Z, sigma)` -- evaluates `fcalc`'s `f0`
  output at `x0` and at small per-parameter perturbations, and warns if
  `f0` is close to zero or any residuals come back non-finite before
  `fillmissing` would have hidden them.
- `runCalibrationFit` now supports `opts.lb` / `opts.ub` (bound `betaf`
  to a physically sensible range, keeping `f0` away from zero) and
  `opts.typicalX` (tell `lsqnonlin` the expected scale of each `betaf`
  entry via `TypicalX` -- badly mismatched parameter scales are another
  common cause of this exact stall pattern).
- Default tolerances were also loosened: the original `1e-10`
  `FunctionTolerance`/`StepTolerance` with `MaxFunctionEvaluations=5000`
  let a stalled fit grind for a very long time before stopping. Defaults
  are now `1e-8` tolerances, `MaxFunctionEvaluations=1000`,
  `MaxIterations=200`, so a stalled fit terminates and reports
  `exitflag`/`output.message` instead of running indefinitely.

Both example scripts now bake in the bounds/solver settings confirmed
working manually:
```matlab
fitOpts.lb = [-3.0;  0.0; -5.0; 0.0];
fitOpts.ub = [ 3.0;  2.0;  0.0; 4.0];
fitOpts.lsqnonlinOpts = optimoptions('lsqnonlin', 'Display','iter', 'MaxFunctionEvaluations',20000);
```
with `TolX`/`TolFun` left at `lsqnonlin`'s defaults. `x0` is now the
simple round-number guess `[0; 1; -2; 2]` -- confirmed to converge (in
~9 iterations) to the same minimum (resnorm ~18300.9) as a separately
fine-tuned hand solution starting point. Two very different starting
points landing on the same minimum is good evidence this is a real,
well-identified solution rather than an artifact of starting near the
answer, so this simple guess is the safer default for future flights
where you won't already know the answer in advance.

### Open items -- please confirm/supply

1. **`fcalc.m` correctness.** The pasted code had a line that couldn't
   have run as written (a `tanBeta(pb,pr)` call before `pb`/`pr` were
   unpacked from `Z`). It was removed as an apparent duplicate/paste
   artifact. Please check the file's header comment and confirm against
   your source.
2. **Dependency functions.** `tanAlpha`, `tanBeta`, `impactPcalc`,
   `fqCalc`, `mach`, `r858_solve3` are assumed to already exist and work
   on your MATLAB path. If any are missing, this won't run.
3. **NetCDF variable name mapping.** `example_calibration_run.m`'s
   `rawVarMap` currently maps each `Z` field to a same-named NetCDF
   variable as a placeholder -- edit it to your real variable names. Run
   `listNetCDFVariables(yourFile)` to see what's available.
4. **Sigma source.** `sigma` is a struct of per-channel uncertainties
   (e.g. `sigma.PTB = 0.1;`), passed straight through to
   `fcalc`/`r858_solve3` unchanged -- see the CONFIG section of either
   example script. Each field can be a fixed scalar or, for the
   windowed-decimation workflow, a calTable column name like `'DP1_std'`
   for a data-driven per-point value instead. **`example_calibration_run_matfile.m`
   also sets `sigma.fcoef` and `sigma.pcor`** (uncertainty on the fitted
   f-coefficient and on the position-error correction) -- these are
   required by `r858_solve3` but aren't per-channel, so they're easy to
   miss if you're building `sigma` from scratch elsewhere. **`sigma.DP1`
   is also now set** -- it was missing from the original manual sigma
   struct, and since `qx1` is built from `DP1` directly, that omission
   meant `predictQTotalUncertainty` was silently skipping what's likely
   the single largest contributor to `qx1`'s real-world uncertainty
   (this is why the computed SE looked implausibly small). The value set
   is a guess -- replace with your actual impact-pressure transducer spec.
5. **Decimation window.** Defaults to 100-sample blocks (or edit
   `timeVar`/`windowSec` for time-based 1-second windows). If your
   calibration methodology requires specific steady-state selection
   (e.g. discard maneuvering segments), plug that logic into
   `decOpts.stabilityFcn` in `example_calibration_run.m`.

### Quick start

```matlab
example_calibration_run_matfile         % your actual data source (.mat, RAW/RATE) -- start here
% example_calibration_run_single_flight % NetCDF-source equivalent, if/when you have NetCDF data
% example_calibration_run               % windowed-decimation alternative, for when a single flight's raw sample count is itself too large
```

---

# NetCDF Multivariate Correction App

*(Below describes the earlier general-purpose linear correction app --
kept for reference / in case it's still useful separately from the
`fcalc` calibration pipeline above.)*

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
