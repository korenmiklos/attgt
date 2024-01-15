{smcl}


{marker attgt-average-treatment-effects-with-staggered-treatment}{...}
{title:{cmd:attgt} Average Treatment Effects with Staggered Treatment}


{marker syntax}{...}
{title:Syntax}

{text}{phang2}{cmd:attgt} {it:depvars}, {bf:treatment}({it:varname}) {bf:aggregate}({it:method}) [{bf:pre}(#) {bf:post}(#) baseline(#) {bf:reps}(#)]{p_end}


{pstd}{cmd:att} computes average treatment effect parameters in Difference in Differences setups with more than two periods and with variation in treatment timing using the methods developed in Callaway and Sant'Anna (2021) {browse "doi:10.1016/j.jeconom.2020.12.001":doi:10.1016/j.jeconom.2020.12.001}. The main parameters are group-time average treatment effects which are the average treatment effect for a particular group at a particular time. These can be aggregated into a fewer number of treatment effect parameters, and the package deals with the cases where there is selective treatment timing, dynamic treatment effects, calendar time effects, or combinations of these.{p_end}

{pstd}The package can be installed with{p_end}

{phang2}{cmd}. net install attgt, from(https://raw.githubusercontent.com/korenmiklos/attgt/main/)


{marker options}{...}
{title:Options}


{marker parameters}{...}
{dlgtab:Parameters}

{synoptset tabbed}{...}
{synopthdr:Parameter}
{synoptline}
{synopt:{bf:treatment}}Dummy variable indicating treatment, e.g., {it:reform}{p_end}
{synopt:{bf:aggregate}}One of the methods (below) to aggregate individual treatment effects.{p_end}
{synoptline}


{marker methods}{...}
{dlgtab:Methods}

{pstd}{it:method} is one of{p_end}

{synoptset tabbed}{...}
{synopthdr:Method}
{synoptline}
{synopt:{bf:gt}}(default) separate ATT for each treatment group {it:g} and calendar time {it:t}{p_end}
{synopt:{bf:att}}one overall ATT, relative to period before treatment{p_end}
{synopt:{bf:prepost}}one overall ATT, relative to the average of {it:pre} periods before treatment{p_end}
{synopt:{bf:e}}aggregate ATT by event time (0 denotes the period {it:before} treatment){p_end}
{synoptline}


{marker options-1}{...}
{dlgtab:Options}

{synoptset tabbed}{...}
{synopthdr:Option}
{synoptline}
{synopt:{bf:pre}}Number of periods before treatment to include in the estimation (does not apply to {it:att}){p_end}
{synopt:{bf:post}}Number of periods after treatment to include in the estimation{p_end}
{synopt:{bf:ipw}}Inverse probability weighting following Abadie (2005){p_end}
{synopt:{bf:reps}}Number of repetitions for boostrap (default = 199){p_end}
{synopt:{bf:baseline}}Baseline period to compare ATET against (default = -1){p_end}
{synopt:{bf:generate} (optional)}Name of the frame to store the coefficients and their confidence interval.{p_end}
{synoptline}


{marker remarks}{...}
{dlgtab:Remarks}

{pstd}The command requires a panel dataset declared by {cmd:xtset}.{p_end}

{pstd}The command also returns, as part of {cmd:e()}, the coefficients and standard errors. See {cmd:ereturn list} after running the command.{p_end}

{pstd}If the {cmd:generate} option is used, the returned frame contains the following variables:{p_end}

{text}{phang2}{cmd:time}: the time period relative to the baseline{p_end}
{phang2}{cmd:coef}: the estimated coefficient{p_end}
{phang2}{cmd:lower}: the lower bound of the 95% confidence interval{p_end}
{phang2}{cmd:upper}: the upper bound of the 95% confidence interval{p_end}


{pstd}The frame is {cmd:tsset} by {cmd:time}, so {cmd:tsline} can be used to plot the event study.{p_end}

{pstd}The command does not allow for {cmd:if} and {cmd:in} clauses. If you need to limit the sample, use{p_end}

{phang2}{cmd}. preserve
keep if ... in ...
attgt ...
restore


{marker examples}{...}
{title:Examples}

{phang2}{cmd}. use https://friosavila.github.io/playingwithstata/drdid/lalonde.dta, clear

{phang2}{cmd}. xtset id year

{phang2}{cmd}. attgt re, treatment(experimental) aggregate(gt)


{marker authors}{...}
{title:Authors}

{text}{phang2}Miklós Koren (Central European University), {it:maintainer}{p_end}



{marker license-and-citation}{...}
{title:License and Citation}

{pstd}You are free to use this package under the terms of its {browse "LICENSE":license}. If you use it, please cite {it:both} the original article and the software package in your work:{p_end}

{text}{phang2}Callaway, Brantly, and Pedro H. C. Sant’Anna. 2021. “Difference-in-Differences with Multiple Time Periods.” Journal of Econometrics 225 (2): 200–230.{p_end}
{phang2}Koren, Miklós. 2023. "ATTGT: Average Treatment Effects with Staggered Treatment. [software]" Available at {browse "https://github.com/korenmiklos/attgt":https://github.com/korenmiklos/attgt}{p_end}


{pstd}The code has been inspired by Rios-Avila, Sant’Anna, Callaway and Naqvi (2021).{p_end}


{marker references}{...}
{title:References}

{text}{phang2}Abadie, Alberto. 2005. “Semiparametric Difference-in-Differences Estimators.” {it:The Review of Economic Studies} 72 (1): 1–19.{p_end}
{phang2}Callaway, Brantly, and Pedro H. C. Sant’Anna. 2021. “Difference-in-Differences with Multiple Time Periods.” Journal of Econometrics 225 (2): 200–230.{p_end}
{phang2}Rios-Avila, Fernando, Pedro H. C. Sant’Anna, Brantly Callaway, and Asjad Naqvi. 2021. “csdid and drdid: Doubly Robust Differences-in-Differences with Multiple Time Periods. [software]” Available at {browse "https://github.com/friosavila/csdid_drdid":https://github.com/friosavila/csdid_drdid}{p_end}
