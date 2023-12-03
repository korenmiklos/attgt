*! version 0.4.1 03dec2023
program attgt, eclass
	syntax varlist, treatment(varname) [ipw(varlist)]	[aggregate(string)] [pre(integer 999)] [post(integer 999)] [reps(int 199)] [notyet] [debug] [cluster(varname)] [weightprefix(string)] [treatment2(varname)]

	* boostrap
	local B `reps'

	* read method of aggregation
	if ("`aggregate'"=="") {
		local aggregate gt
	}
	assert inlist("`aggregate'", "gt", "e", "att", "prepost")
	if ("`aggregate'"=="att") {
		* if we only compute ATT, no need to check pre-trends
		local pre 0
	}

	tempvar ipweight
	quietly generate `ipweight' = 1

	* read panel structure
	xtset
	local i = r(panelvar)
	local time = r(timevar)

	if ("`treatment2'" != "") {
		capture assert "`tyet'" == ""
		if _rc {
			display in red "notyet incompatible with treatment2"
			error 9
		}
		tempvar group2
		quietly egen `group2' = min(cond(`treatment2', `time'-1, .)), by(`i')
		* FIXME: range of group2 may not be the same as group. what to do with these treatment times?
	}

	* test that cluster embeds ivar
	if ("`cluster'"!="") {
		tempvar g1 g2
		tempname max1 max2
		quietly egen `g1' = group(`i')
		quietly summarize `g1'
		scalar `max1' = r(max)
		quietly egen `g2' = group(`i' `cluster')
		quietly summarize `g2'
		scalar `max2' = r(max)
		assert `max2'==`max1'
		drop `g1' `g2'
	}
	else {
		local cluster `i'
	}

	tempvar group _alty_ _y_ flip
	tempname b V v att co tr _tr_
	quietly egen `group' = min(cond(`treatment', `time'-1, .)), by(`i')
	quietly summarize `time'
	local min_time = r(min)
	local max_time = r(max)
	quietly summarize `group'
	local min_g = r(min)
	local max_g = r(max)
	* feasible event windows
	local max_pre = min(`max_g' - `min_time', `pre')
	local max_post = min(`max_time' - `min_g', `post')
	
	* estimate ATT(g,t) as eq 2.6 in https://pedrohcgs.github.io/files/Callaway_SantAnna_2020.pdf
	quietly levelsof `group' if `group' > `min_time', local(gs)
	quietly levelsof `time', local(ts)

	* check that valid weights exist for each treatment group
	if ("`weightprefix'" != "") {
		foreach g in `gs' {
			confirm numeric variable `weightprefix'`g'
			capture assert `weightprefix'`g' >= 0, fast
			if _rc {
				display in red "Weights must be non-negative. Offending weight:  `weightprefix'`g'"
				error 9
			}
			tempvar i1 i2
			* check that weight does not vary within ivar
			quietly egen `i1' = group(`i')
			quietly egen `i2' = group(`i' `weightprefix'`g')
			quietly summarize `i1'
			local m1 = r(max)
			quietly summarize `i2'
			local m2 = r(max)
			capture assert `m1' == `m2'
			if _rc {
				display in red "Weights cannot vary within `i'. Offending weight:  `weightprefix'`g'"
				error 9
			}
			drop `i1' `i2'
		}
	}
	else {
		tempvar one
		quietly generate byte `one' = 1
	}

	* FIXME: check that g = min_time is not used as control
	* create design matrix
	display "Generating weights..."
	if ("`ipw'" != "") {
		tempvar TD_global phat_global
		tempname AIC_global
		if ("`tyet'"=="") {
			if "`treatment2'" != "" {
				local control (`group2'==`time')
			}
			else {
				* never treated
				local control missing(`group')
			}
		}
		else {
			* not yet treated
			local control (missing(`group') | (`group' > `time'))
		}
		* NB: without limitcontrol this was bad because included post-treatment years as control
		quietly generate `TD_global' = (`group' == `time') if (`control' | (`group' == `time'))
	 	capture probit `TD_global' `ipw' i.`time' if (`control' | (`group' == `time'))
		quietly predict `phat_global' if (`control' | (`group' == `time')), pr
	}
	foreach g in `gs' {
		if ("`weightprefix'" != "") {
			local cweight `weightprefix'`g'
		}
		else {
			local cweight `one'
		}
		* FIXME: this only calculate IPW for one set of control group.
		if ("`ipw'" != "") {
			tempvar TD phat ph2 ph3
			tempname AIC
			local treated (`group'==`g')
			if ("`tyet'"=="") {
				if "`treatment2'" != "" {
					local control (`group2'==`g')
				}
				else {
					* never treated
					local control missing(`group')
				}
			}
			else {
				* not yet treated
				local control (missing(`group') | (`group' > `g'))
			}
			quietly generate byte `TD' = `treated'
		 	capture probit `TD' `ipw' if (`treated' | `control') & (`time' == `g')
			* only use well fitting probits
			if (_rc==0) & (e(p) < 0.05) {
				quietly predict `phat' if `control' & (`time' == `g'), pr
				* if probit predicts failure or success perfectly, use boundary values
				quietly egen `ph2' = mean(`TD') if (`treated' | `control') & (`time' == `g') & missing(`phat')
				quietly replace `phat' = `ph2' if `control' & (`time' == `g') & missing(`phat')
				* trim values to not give extreme weights to any one observation
				quietly replace `phat' = 0.999 if (`phat' > 0.999 & !missing(`phat')) & `control' & (`time' == `g')
			}
			* otherwise stick to globally estimated probit
			else {
				* if cannot estimate propensity scores due to perfect fit of regression, no observations will be used as a control
				quietly generate `phat' = `phat_global' if `control'
			}
			quietly egen `ph3' = max(`phat' / (1 - `phat')) if `control', by(`i')
			quietly replace `ipweight' = `ph3' if `control'
		}
		foreach t in `ts' {
		if (`g'!=`t') & (`g'>`min_time') & (`t' - `g' <= `post') & (`g' - `t' <= `pre') {
			* within (g,t), panel has to be balanced
			mata: st_local("leadlag1", lead_lag(`g', `t'))
			mata: st_local("leadlag2", lead_lag(`t', `g'))
			local timing (`time'==`g' & `leadlag1'.`time'==`t') | (`time'==`t' & `leadlag2'.`time'==`g')
			local treated (`group'==`g') & (`timing')
			if ("`tyet'"=="") {
				if "`treatment2'" != "" {
					local control (`group2'==`g') & (`timing')
				}
				else {
					* never treated
					local control missing(`group') & (`timing')
				}
			}
			else {
				* not yet treated
				local control (missing(`group') | (`group' > max(`g', `t'))) & (`timing')
			}

			quietly count if `treated'
			local n_treated = r(N)/2
			tempvar sumw_control ctrl
			quietly generate byte `ctrl' = `control'
			quietly egen `sumw_control' = total(`ipweight') if `ctrl', by(`time')
			quietly count if `control' & `ipweight'!=0 & !missing(`ipweight')
			local n_control = r(N)/2
			local n_`g'_`t' = `n_treated' * `n_control' / (`n_treated' + `n_control')

			tempvar treated_`g'_`t' control_`g'_`t'
			quietly generate `treated_`g'_`t'' = cond(`time'==`t', +1/`n_treated', -1/`n_treated') if `treated'
			quietly generate `control_`g'_`t'' = cond(`time'==`t', `ipweight'/`sumw_control', -`ipweight'/`sumw_control') if `control'
		}
		}
	}

	if ("`aggregate'"=="e") {
		tempname n_e
		forvalues e = `max_pre'(-1)1 {
			scalar `n_e' = 0
			tempvar event_m`e' wce_m`e'
			quietly generate `event_m`e'' = 0
			quietly generate `wce_m`e'' = 0
			foreach g in `gs' {
				local t = `g' - `e'
				if (`t' >= `min_time') & ("`n_`g'_`t''" != "") {
					quietly replace `event_m`e'' = `event_m`e'' + `n_`g'_`t''*`treated_`g'_`t'' if !missing(`treated_`g'_`t'')
					quietly replace `wce_m`e'' = `wce_m`e'' + `n_`g'_`t''*`control_`g'_`t'' if !missing(`control_`g'_`t'')
					scalar `n_e' = `n_e' + `n_`g'_`t''
				}
			}
			quietly replace `event_m`e'' = `event_m`e'' / `n_e' 
			quietly replace `wce_m`e'' = `wce_m`e'' / `n_e' 
			local tweights `tweights' event_m`e'
			local cweights `cweights' wce_m`e'
		}
		forvalues e = 1/`max_post' {
			scalar `n_e' = 0
			tempvar event_`e' wce_`e'
			quietly generate `event_`e'' = 0
			quietly generate `wce_`e'' = 0
			foreach g in `gs' {
				local t = `g' + `e'
				if (`t' <= `max_time') & ("`n_`g'_`t''" != "") {
					quietly replace `event_`e'' = `event_`e'' + `n_`g'_`t''*`treated_`g'_`t'' if !missing(`treated_`g'_`t'') 
					quietly replace `wce_`e'' = `wce_`e'' + `n_`g'_`t''*`control_`g'_`t'' if !missing(`control_`g'_`t'')
					scalar `n_e' = `n_e' + `n_`g'_`t''
				}
			}
			quietly replace `event_`e'' = `event_`e'' / `n_e' 
			quietly replace `wce_`e'' = `wce_`e'' / `n_e' 
			local tweights `tweights' event_`e'
			local cweights `cweights' wce_`e'
		}
	}
	if ("`aggregate'"=="gt") {
			foreach g in `gs' {
				foreach t in `ts' {
				if (`g'!=`t') & (`g'>`min_time') & ("`n_`g'_`t''" != "") {
					local tweights `tweights' treated_`g'_`t'
					local cweights `cweights' control_`g'_`t'
				}
				}
			}
	}
	if ("`aggregate'"=="att") {
			tempname n
			tempvar att control
			quietly generate `att' = 0
			quietly generate `control' = 0
			scalar `n' = 0
			foreach g in `gs' {
				foreach t in `ts' {
				if (`g' < `t') & (`g'>`min_time') & (`t' - `g' <= `post') & ("`n_`g'_`t''" != "") {
					quietly replace `att' = `att' + `n_`g'_`t''*`treated_`g'_`t'' if !missing(`treated_`g'_`t'')
					quietly replace `control' = `control' + `n_`g'_`t''*`control_`g'_`t'' if !missing(`control_`g'_`t'')
					scalar `n' = `n' + `n_`g'_`t''
				}
				}
			}
			quietly replace `att' = `att' / `n' 
			quietly replace `control' = `control' / `n' 
			local tweights att
			local cweights control
	}
	if ("`aggregate'"=="prepost") {
		tempname n1 n2
		tempvar att wce att1 wce1 att2 wce2
		scalar `n1' = 0
		quietly generate `att1' = 0
		quietly generate `wce1' = 0
		forvalues e = `max_pre'(-1)1 {
			foreach g in `gs' {
				local t = `g' - `e'
				if (`t' >= `min_time') & ("`n_`g'_`t''" != "") {
					quietly replace `att1' = `att1' - `n_`g'_`t''*`treated_`g'_`t'' if !missing(`treated_`g'_`t'')
					quietly replace `wce1' = `wce1' - `n_`g'_`t''*`control_`g'_`t'' if !missing(`control_`g'_`t'')
					scalar `n1' = `n1' + `n_`g'_`t''
				}
				* add the zeros
				quietly count if (`time' == `g') & (`group' == `g')
				scalar `n1' = `n1' + r(N)/2
			}
		}
		scalar `n2' = 0
		quietly generate `att2' = 0
		quietly generate `wce2' = 0
		forvalues e = 1/`max_post' {
			foreach g in `gs' {
				local t = `g' + `e'
				if (`t' <= `max_time') & ("`n_`g'_`t''" != "") {
					quietly replace `att2' = `att2' + `n_`g'_`t''*`treated_`g'_`t'' if !missing(`treated_`g'_`t'')
					quietly replace `wce2' = `wce2' + `n_`g'_`t''*`control_`g'_`t'' if !missing(`control_`g'_`t'')
					scalar `n2' = `n2' + `n_`g'_`t''
				}
			}
		}
		quietly generate `att' = `att1' / `n1' + `att2' / `n2' 
		quietly generate `wce' = `wce1' / `n1' + `wce2' / `n2'
		local tweights `tweights' att
		local cweights `cweights' wce
	}

	tempvar esample
	quietly generate byte `esample' = 0

	* aggregate across known weights
	quietly generate `_alty_' = .
	quietly generate `_y_' = .
	quietly generate byte `flip' = 0
	local nw : word count `tweights'
	foreach y of var `varlist' {
		forvalues n = 1/`nw' {
			quietly replace `_alty_' = .
			quietly replace `_y_' = .

			local tw : word `n' of `tweights'
			local cw : word `n' of `cweights'

			* set estimation sample
			quietly replace `esample' = 1 if ((``tw'' != 0 & !missing(``tw'')) | (``cw'' != 0 & !missing(``cw'')))

			display "Estimating `y': `tw'"

			mata: st_numscalar("`co'", sum_product("`y' ``cw''"))
			mata: st_numscalar("`tr'", sum_product("`y' ``tw''"))
			matrix `att' = `tr' - `co'

			* wild bootstrap with Rademacher weights requires flipping the error term
			quietly replace `_y_' = cond(``tw''>0, `y' - `tr', `y') if ``tw'' !=0 & !missing(``tw'')
			quietly replace `_alty_' = cond(``tw''>0, `tr' - `y', -`y') if ``tw'' !=0 & !missing(``tw'')
			quietly replace `_y_' = cond(``cw''>0, `y' - `co', `y') if ``cw'' !=0 & !missing(``cw'')
			quietly replace `_alty_' = cond(``cw''>0, `co' - `y', -`y') if ``cw'' !=0 & !missing(``cw'')

			set seed 4399
			mata: st_numscalar("`v'", bs_variance("`_y_' `_alty_' ``tw'' ``cw'' `cluster'", `B', 1))
			matrix `b' = nullmat(`b'), `att'
			matrix `V' = nullmat(`V'), `v'
			local eqname `eqname' `y'
			local colname `colname' `tw'
		}
	}
	matrix `V' = diag(`V')
	matrix colname `b' = `colname'
	matrix coleq   `b' = `eqname'
	matrix colname `V' = `colname'
	matrix coleq   `V' = `eqname'
	matrix rowname `V' = `colname'
	matrix roweq   `V' = `eqname'

	quietly count if `esample' == 1
	local Nobs = r(N)

	ereturn post `b' `V', obs(`Nobs') esample(`esample')
	ereturn local cmd attgt
	ereturn local cmdline attgt `0'
	ereturn local treatment `treatment'
	display "Callaway Sant'Anna (2021)"
	* Use Stata's built-in but undocumented estimation display
	_prefix_display

end

mata:
string scalar lead_lag(real scalar g, real scalar t)
{
	if (t > g) {
		return("F" + strofreal(t - g))
	}
	else {
		return("L" + strofreal(g - t))
	}
}

string scalar minus(real scalar t)
{
	if (t >= 0) {
		return(strofreal(t))
	}
	else {
		return("m" + strofreal(-t))
	} 
}

real scalar sum_product(string matrix vars)
{
	X = 0
	st_view(X, ., vars, 0)
	return(colsum(X[1...,1] :* X[1...,2]))
}

real scalar bs_variance(string matrix vars, real scalar B, real scalar cluster)
{
	X = 0
	st_view(X, ., vars)
	N = rows(X)
	Y = J(N, 1, 0)
	theta = J(B, 1, .)

	if (cluster==1) {
		group = recode(X[1..., 5])
		K = max(group)
	}
	else {
		group = 1::N
		K = N
	}

	for (i=1; i<=B; i++) {
		flip = rdiscrete(K, 1, (0.5, 0.5))

		for (n=1; n<=N; n++) {
			Y[n,1] = X[n, 1..2][flip[group[n]]]
		}

		theta[i, 1] = colsum(Y :* X[1..., 3]) - colsum(Y :* X[1..., 4])
	}
	return((variance(theta))[1,1])
}

real vector recode(real vector x)
{
	N = rows(x)
	levelsof = uniqrows(x)
	G = rows(levelsof)
	output = J(N, 1, 0)
	for (n=1; n<=N; n++) {
		output[n] = min(selectindex(levelsof :== x[n]))
	}
	return(output)
}

real matrix build_index(real vector ivar, real vector tvar)
{
	N = colmax(ivar)
	T = colmax(tvar)

	index = J(N, T, 0)
	for (i=1; i<=N; i++) {
		for (t=1; t<=T; t++) {
			loc = selectindex((ivar :== i) :& (tvar :== t))
			if (rows(loc) & cols(loc)) {
				index[i, t] = loc[1]
			}
		}
	}
	return(index)
}

void difference_baseline(string scalar vars)
{
	real matrix YX
	st_view(YX, ., vars)

	ivar = YX[., 3]
	tvar = YX[., 4]
	gvar = YX[., 5]

	T = colmax(tvar)
	N = colmax(ivar)

	index = build_index(ivar, tvar)
	printf("503,7 = %f", index[503,7])

	for (i=1; i<=N; i++) {
		for (g=1; g<=T; g++) {
			if (index[i, g] > 0) {
				baseline = YX[index[i, g], 2]
			}
			else {
				baseline = .
			}
			for (t=1; t<=T; t++) {
				if (index[i, t] > 0) {
					gg = gvar[index[i, t]]
					if (gg > 0) {
						if (index[i, gg] > 0) {
							YX[index[i, t], 1] = YX[index[i, t], 2] - YX[index[i, gg], 2]
						}
					}
				}
			}
		}
	}
}

end