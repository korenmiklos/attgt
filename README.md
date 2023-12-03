---
author: Koren, Miklós (https://koren.mk)
date: 2023-12-03
version: 0.4.1
title: ATTGT - Average Treatment Effects with Staggered Treatment
description: |
    `att` computes average treatment effect parameters in Difference in Differences setups with more than two periods and with variation in treatment timing using the methods developed in Callaway and Sant'Anna (2021) <doi:10.1016/j.jeconom.2020.12.001>. The main parameters are group-time average treatment effects which are the average treatment effect for a particular group at a particular time. These can be aggregated into a fewer number of treatment effect parameters, and the package deals with the cases where there is selective treatment timing, dynamic treatment effects, calendar time effects, or combinations of these.
url: https://github.com/korenmiklos/attgt
requires: Stata version 16
files: 
    - attgt.ado
    - attgt.sthlp
    - LICENSE
    - testdata.dta 
---
# `attgt` Average Treatment Effects with Staggered Treatment

# Syntax

- `attgt` *depvars*, **treatment**(*varname*) **aggregate**(*method*) [**pre**(#) **post**(#) **ipw**(*varlist*) **reps**(#)]

`att` computes average treatment effect parameters in Difference in Differences setups with more than two periods and with variation in treatment timing using the methods developed in Callaway and Sant'Anna (2021) <doi:10.1016/j.jeconom.2020.12.001>. The main parameters are group-time average treatment effects which are the average treatment effect for a particular group at a particular time. These can be aggregated into a fewer number of treatment effect parameters, and the package deals with the cases where there is selective treatment timing, dynamic treatment effects, calendar time effects, or combinations of these.

The package can be installed with
```
net install attgt, from(https://raw.githubusercontent.com/korenmiklos/attgt/v0.4.0/)
```

# Options
## Parameters
Parameter | Description
-------|------------
**treatment** | Dummy variable indicating treatment, e.g., *reform*
**aggregate** | One of the methods (below) to aggregate individual treatment effects.

## Methods
*method* is one of

Method | Description
------|------------
**gt** | (default) separate ATT for each treatment group *g* and calendar time *t*
**att** | one overall ATT, relative to period before treatment
**prepost** | one overall ATT, relative to the average of *pre* periods before treatment
**e** | aggregate ATT by event time (0 denotes the period *before* treatment)

## Options
Option | Description
-------|------------
**pre** | Number of periods before treatment to include in the estimation (does not apply to *att*)
**post** | Number of periods after treatment to include in the estimation
**ipw** | Inverse probability weighting following Abadie (2005)
**reps** | Number of repetitions for boostrap (default = 199)

## Remarks

The command requires a panel dataset declared by `xtset`. 

The command also returns, as part of `e()`, the coefficients and standard errors. See `ereturn list` after running the command.

The command does not allow for `if` and `in` clauses. If you need to limit the sample, use
```
preserve
keep if ... in ...
attgt ...
restore
``` 

# Examples
```
use https://friosavila.github.io/playingwithstata/drdid/lalonde.dta, clear
```
```
xtset id year
```
```
attgt re, treatment(experimental) aggregate(gt)
```

# Authors
- Miklós Koren (Central European University), *maintainer*

# License and Citation
You are free to use this package under the terms of its [license](LICENSE). If you use it, please cite *both* the original article and the software package in your work:

- Callaway, Brantly, and Pedro H. C. Sant’Anna. 2021. “Difference-in-Differences with Multiple Time Periods.” Journal of Econometrics 225 (2): 200–230.
- Koren, Miklós. 2023. "ATTGT: Average Treatment Effects with Staggered Treatment. [software]" Available at https://github.com/korenmiklos/attgt

The code has been inspired by Rios-Avila, Sant’Anna, Callaway and Naqvi (2021).

# References
- Abadie, Alberto. 2005. “Semiparametric Difference-in-Differences Estimators.” *The Review of Economic Studies* 72 (1): 1–19.
- Callaway, Brantly, and Pedro H. C. Sant’Anna. 2021. “Difference-in-Differences with Multiple Time Periods.” Journal of Econometrics 225 (2): 200–230.
- Rios-Avila, Fernando, Pedro H. C. Sant’Anna, Brantly Callaway, and Asjad Naqvi. 2021. “csdid and drdid: Doubly Robust Differences-in-Differences with Multiple Time Periods. [software]” Available at https://github.com/friosavila/csdid_drdid
