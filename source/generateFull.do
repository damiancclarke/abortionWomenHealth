/* generateFull v0.00            damiancclarke             yyyy-mm-dd:2018-07-23
----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8


*/

vers 12
clear all
set more off
cap log close

********************************************************************************
*** (1) Globals and locals
********************************************************************************
global DAT "/mnt/SDD-2/database/MexDemografia/Hospital/dta"
global DAT  "/mnt/SDD-2/database/MexDemografia/"
global DAT  "~/database/MexDemografia/"
global OUT "~/investigacion/2018/ILE-health/data/"
global POP "~/investigacion/2018/ILE-health/data/population"
global LOG "~/investigacion/2018/ILE-health/log"

log using "$LOG/generateFull.txt", text replace


********************************************************************************
*** (2) Population
********************************************************************************
use "$POP/populationStateYear", clear
drop month
reshape long year_, i(stateName Age stateNum) j(Year)
rename year_ population
keep if Age>=15&Age<=44
collapse (sum) population, by(stateName stateNum Year) fast
rename Year year 
keep if year>=1990&year<=2016

#delimit ;
local snum 29 12 09 17 03 28 10 01 32 04 22 14 26 07 25 16 30 23 13 05 21 27
           19 15 18 02 24 06 31 11 20 08;
#delimit cr
gen estado = .
local i = 1
foreach num in `snum' {
    replace estado = `i' if stateNum=="`num'"
    local ++i
}
destring stateNum, replace
tempfile population
save `population'

********************************************************************************
*** (3) Mortality
********************************************************************************
#delimit ;
local yrs 90 91 92 93 94 95 96 97 98 99 00 01 02 03 04 05 06 07 08 09 10 11 12
          13 14 15 16;
#delimit cr
local j = 1
local mfiles
foreach yr in `yrs' {
    dis "Working with `yr'"
    use "$DAT/DefuncionesGenerales/DEFUN`yr'.dta", clear
    #delimit ;
    keep ent_regis mun_regis ent_resid mun_resid ent_ocurr mun_ocurr
    causa_def sexo edad mes_ocurr anio_ocur
    mes_nacim anio_nacim ocupacion escolarida edo_civil presunto
    asist_medi nacionalid maternas;
    #delimit cr
    replace edad=.       if edad==4998
    replace mun_resid=.  if mun_resid==999
    replace mun_ocurr=.  if mun_ocurr==999
    replace ent_resid=.  if ent_resid==99
    replace mes_ocurr=.  if mes_ocurr==99
    replace anio_ocur=.  if anio_ocur==9999
    replace anio_nacim=. if anio_nacim==9999

    gen maternalDeath = maternas!=""
    gen ICD3 = substr(causa_def,1,3)
    gen ICD2 = substr(causa_def,1,2)
    gen abortiveDeaths = ICD2=="O0"|ICD3=="O20" 
    if `j'<9 {
        replace anio_ocur=. if anio_ocur==99
        replace anio_ocur=anio_ocur+1900
    }
    keep if anio_ocur>=1990&anio_ocur<=2016
    rename anio_ocur year

    rename edad age
    keep if age>=4001&age<=4120
    replace age=age-4000


    rename ent_ocurr estado
    *rename ent_resid stateNum

    keep maternalDeath age estado year abortiveDeaths
    tempfile M`yr'
    save `M`yr''
    local mfiles `mfiles' `M`yr''
    local ++j
}
clear
append using `mfiles'

collapse (sum) maternalDeath abortiveDeaths, by(estado year) fast
drop if estado>32
tempfile mortality
save `mortality'

********************************************************************************
*** (4) Natality
********************************************************************************
local j = 1
local ffiles
foreach yr in `yrs' {
    dis "Working with `yr'"
    use "$DAT/Natalidades/NACIM`yr'.dta", clear

    #delimit ;
    local v999 mun_resid mun_ocurr;
    local v99  tloc_resid ent_ocurr edad_reg edad_madn edad_padn
    mes_nac mes_reg edad_madr edad_padr orden_part hijos_vivo
    hijos_sobr sexo tipo_nac lugar_part q_atendio edociv_mad act_pad
    escol_pad escol_mad fue_prese act_mad;
    #delimit cr
    foreach v of local v999 {
        replace `v'=. if `v'==999
    }
    foreach v of local v99  {
        replace `v'=. if `v'==99
    }
    replace ano_nac=. if ano_nac==9999
    gen birth=1

    if `j'<9 {
        replace ano_nac=. if ano_nac==99
        replace ano_nac=ano_nac+1900
    }
    keep if ano_nac>=1990&ano_nac<=2013

    *gen difyr=ano_reg-ano_nac
    *keep if difyr>=0&difyr<=3

    count if ent_ocurr==ent_resid
    local Nsame = `=`r(N)''
    local kept `kept' `Nsame'
    count
    local Ntot  = `=`r(N)''
    local totl `totl' `Ntot'

    rename edad_madn age

    rename ent_ocurr estado
    *rename ent_resid stateNum

    rename ano_nac year
    keep if age>=15&age<=49
    keep birth age estado year

    tempfile F`yr'
    save `F`yr''
    local ffiles `ffiles' `F`yr''
    local ++j
}
clear
append using `ffiles'


collapse (sum) birth, by(estado year) fast
keep if estado<=32
tempfile natality
save `natality'


********************************************************************************
*** (5) Append Social Security Hospitals with Secretary of Health Hospitals
********************************************************************************
use "$DAT/Hospital/dta/BDSS_consolidate.dta", clear 

keep if sexo==2
keep if edad>14 & edad<50
gen cases = 1
gen DF=estado==9
drop if year<2004
drop if year==.

replace ICD_3 = subinstr(ICD_3, " ", "", .)
gen ICD_1 = substr(ICD_3,1,1)
rename ICD_3 ICD_3x
gen ICD_3 = substr(ICD_3x,1,3)
replace dias_esta = 0 if dias_esta<0
replace dias_esta = 100 if dias_esta>100&dias_esta!=.

*keep if ICD_1 == "O"|afecprin=="Z303"

tempfile OBDSS
save `OBDSS'


use "$DAT/Hospital/dta/SAEH_consolidate.dta", clear 
keep if sexo==2
keep if edad>14 & edad<50
gen cases = 1
gen DF=estado==9
drop if year<2000
drop if year==.
replace dias_esta = 0 if dias_esta<0
replace dias_esta = 100 if dias_esta>100&dias_esta!=.

gen ICD_4 = substr(afecprin,1,4)
gen ICD_3 = substr(afecprin,1,3)
gen ICD_1 = substr(afecprin,1,1)
*keep if ICD_1 == "O"|ICD_4=="Z303"
gen date = year+(mes-1)/12
append using `OBDSS'
keep if year>=2004
keep if estado<=32
#delimit ;
gen abortionRelated = ICD_3=="O02"|ICD_3=="O03"|ICD_3=="O04"|ICD_3=="O05"|
                      ICD_3=="O06"|ICD_3=="O07"|ICD_3=="O08";
gen abortionRelatedNZ = abortionRelated==1&dias_esta!=0;
gen deliveries      = ICD_3=="O80"|ICD_3=="O81"|ICD_3=="O82"|ICD_3=="O83"|
                      ICD_3=="O84";
gen haemorrhage     = ICD_3=="O20";
gen infection       = ICD_3=="O23";
gen O02             = ICD_3=="O02";
gen O03             = ICD_3=="O03";
gen O04             = ICD_3=="O04";
gen O05             = ICD_3=="O05";
gen O06             = ICD_3=="O06";
gen O07             = ICD_3=="O07";
gen O08             = ICD_3=="O08";
gen totalNonBirth   = deliveries!=1;
gen totalONonBirth  = ICD_1=="O"&deliveries!=1;
gen abortComplic    = abortionRelated;
replace abortComplic= 0 if ICD_4=="O034"|ICD_4=="O039"|ICD_4=="O044"|
                           ICD_4=="O049"|ICD_4=="O054"|ICD_4=="O059"|
                           ICD_4=="O064"|ICD_4=="O069"|ICD_4=="O074"|
                           ICD_4=="O079"|ICD_3=="O02";
gen abortNoComplic = abortionRelated;
replace abortNoComplic = 0 if abortComplic==1;
gen extraction = ICD_4=="Z303";
#delimit cr

local amorb abortionRelated abortionRelatedNZ O0* total*
local omorb deliveries haemorrhage extraction infection
local days
foreach var of varlist `amorb' `omorb' {
    gen days_`var' = dias_esta if `var'==1
    local days `days' days_`var'
}
collapse (sum) `amorb' `omorb' `days', by(year estado) fast
tempfile mort
save `mort'

********************************************************************************
*** (6) Private morbidity data
********************************************************************************
insheet using "$OUT/morbidity/macroTrends.csv", comma names clear
gen abortion    = smoclave==307|smoclave==308|smoclave==309
gen haemorrhage = smoclave==315
collapse (sum) smomuje, by(abortion haemorrhage anio entidad)
drop if abortion==0 & haemorrhage==0
gen haemorrhage_private = smomuje if haemorrhage==1
gen abortion_private    = smomuje if abortion==1

collapse (sum) haemorrhage_private abortion_private, by(anio entidad)
rename anio year
rename entidad estado
tempfile morbPriv
save `morbPriv'

********************************************************************************
*** (7) Controls
********************************************************************************
use "$OUT/states/SeguroPopular",
drop if year==2000
collapse T, by(statemx year)
rename statemx estado
rename T SP
drop if estado==.
tempfile SP
save `SP'

insheet using "$OUT/states/stateControls.csv", comma names clear
expand 2 if year==2015, gen(generated)
replace year = 2016 if generated==1
drop generated
foreach var of varlist homicides-gdppc {
    bys estado: ipolate `var' year, gen(`var'_i) epolate
    sum `var' `var'_i
    drop `var'
    rename `var'_i `var'
}
merge 1:1 estado year using `SP'
replace SP = 1 if _merge==1
drop _merge
keep SP poverty accesshealth aveschool womenactiveecon avesalary
tempfile controls
save `controls'


********************************************************************************
*** (6) Put together
********************************************************************************
use `population'

merge 1:1 year estado using `mortality'
drop _merge

merge 1:1 year estado using `natality'
drop _merge

merge 1:1 year estado using `mort'
drop _merge

merge 1:1 year estado using `controls'
drop _merge

merge 1:1 year estado using `morbPriv'
drop _merge

********************************************************************************
*** (7) Reform dates + created variables
********************************************************************************
#delimit;
gen regressiveState=stateName=="BajaCalifornia"|stateName=="Chiapas"
|stateName=="Chihuahua"|stateName=="Colima"|stateName=="Durango"
|stateName=="Guanajuato"|stateName=="Jalisco"|stateName=="Morelos"
|stateName=="Nayarit"|stateName=="Oaxaca"|stateName=="Puebla"
|stateName=="Queretaro"|stateName=="QuintanaRoo"|stateName=="SanLuisPotosi"
|stateName=="Sonora"|stateName=="Tamaulipas"|stateName=="Yucatan"
|stateName=="Veracruz"|stateName=="Campeche";
#delimit cr
generat regressiveY = 1 if year >= 2009 & stateName=="BajaCalifornia"
replace regressiveY = 1 if year >= 2009 & stateName=="Chiapas"
replace regressiveY = 1 if year >= 2009 & stateName=="Chihuahua"
replace regressiveY = 1 if year >= 2010 & stateName=="Colima"
replace regressiveY = 1 if year >= 2009 & stateName=="Durango"
replace regressiveY = 1 if year >= 2009 & stateName=="Guanajuato"
replace regressiveY = 1 if year >= 2010 & stateName=="Jalisco"
replace regressiveY = 1 if year >= 2009 & stateName=="Morelos"
replace regressiveY = 1 if year >= 2010 & stateName=="Nayarit"
replace regressiveY = 1 if year >= 2010 & stateName=="Oaxaca"
replace regressiveY = 1 if year >= 2010 & stateName=="Puebla"
replace regressiveY = 1 if year >= 2010 & stateName=="Queretaro"
replace regressiveY = 1 if year >= 2009 & stateName=="QuintanaRoo"
replace regressiveY = 1 if year >= 2010 & stateName=="SanLuisPotosi"
replace regressiveY = 1 if year >= 2009 & stateName=="Sonora"
replace regressiveY = 1 if year >= 2010 & stateName=="Tamaulipas"
replace regressiveY = 1 if year >= 2010 & stateName=="Yucatan"
replace regressiveY = 1 if year >= 2010 & stateName=="Veracruz"
*replace regressive = 1 if year >= 2010 & stateName=="Campeche"
replace regressiveY = 0 if regressiveY!=1

generat regressive = 1 if year >= 2008 & stateName=="BajaCalifornia"
replace regressive = 1 if year >= 2009 & stateName=="Chiapas"
replace regressive = 1 if year >= 2008 & stateName=="Chihuahua"
replace regressive = 1 if year >= 2009 & stateName=="Colima"
replace regressive = 1 if year >= 2009 & stateName=="Durango"
replace regressive = 1 if year >= 2009 & stateName=="Guanajuato"
replace regressive = 1 if year >= 2009 & stateName=="Jalisco"
replace regressive = 1 if year >= 2008 & stateName=="Morelos"
replace regressive = 1 if year >= 2009 & stateName=="Nayarit"
replace regressive = 1 if year >= 2009 & stateName=="Oaxaca"
replace regressive = 1 if year >= 2009 & stateName=="Puebla"
replace regressive = 1 if year >= 2009 & stateName=="Queretaro"
replace regressive = 1 if year >= 2009 & stateName=="QuintanaRoo"
replace regressive = 1 if year >= 2009 & stateName=="SanLuisPotosi"
replace regressive = 1 if year >= 2009 & stateName=="Sonora"
replace regressive = 1 if year >= 2009 & stateName=="Tamaulipas"
replace regressive = 1 if year >= 2009 & stateName=="Yucatan"
replace regressive = 1 if year >= 2009 & stateName=="Veracruz"
*replace regressive = 1 if year >= 2010 & stateName=="Campeche"
replace regressive = 0 if regressive!=1
gen ILE = estado==9&year>=2007

gen DF = estado == 9


lab var stateName        "State's Name"
lab var stateNum         "State's Numerical Code (INEGI)"
lab var year             "Year of Ocurrence"
lab var population       "Population of 15-44 Year-old Women"
lab var estado           "State's Numerical Code (Morbidity)"
lab var maternalDeath    "Number of Maternal Deaths"
lab var abortiveDeaths   "Number of Maternal Deaths due to Abortion"
lab var birth            "Number of Births"
lab var abortionRelated  "Number of Inpatient Visits due to Abortion Related Complications"
lab var O02              "Number of Inpatient Visits due to ICD 002"
lab var O03              "Number of Inpatient Visits due to ICD 003"
lab var O04              "Number of Inpatient Visits due to ICD 004"
lab var O05              "Number of Inpatient Visits due to ICD 005"
lab var O06              "Number of Inpatient Visits due to ICD 006"
lab var O07              "Number of Inpatient Visits due to ICD 007"
lab var O08              "Number of Inpatient Visits due to ICD 008"
lab var totalNonBirth    "Number of Inpatient Visits due to all Morbidity for Women Except Births"
lab var totalONonBirth   "Number of Inpatient Visits due to all ICD O Except Births"
lab var deliveries       "Number of Inpatient Visits due to Child Birth"
lab var haemorrhage      "Number of Inpatient Visits due to Haemorrhage Early in Pregnancy"
lab var extraction       "Number of Inpatient Visits due to Extraction (ILE)"
lab var days_abortionRelated  "Number of Inpatient Days due to Abortion Related Complications"
lab var days_O02         "Number of Inpatient Days due to ICD 002"
lab var days_O03         "Number of Inpatient Days due to ICD 003"
lab var days_O04         "Number of Inpatient Days due to ICD 004"
lab var days_O05         "Number of Inpatient Days due to ICD 005"
lab var days_O06         "Number of Inpatient Days due to ICD 006"
lab var days_O07         "Number of Inpatient Days due to ICD 007"
lab var days_O08         "Number of Inpatient Days due to ICD 008"
lab var days_deliverie   "Number of Inpatient Days due to Child Birth"
lab var days_haemorrh    "Number of Inpatient Days due to Haemorrhage Early in Pregnancy"
lab var haemorrhage_priv "Number of Inpatient visits due to Haemorrhage etc Private"
lab var abortion_private "Number of Inpatient Visits due to Abortion in Private System"
lab var SP               "Percent of Municipalities with Seguro Popular Coverage"
lab var poverty          "Percent of State Living Below Poverty Line"
lab var accesshealth     "Percent of State Residents with Access to Health Institutions"
lab var aveschool        "Average Schooling of Adult Population"  
lab var womenactiveecon  "Percent of Women of Working Age Economically Active"
lab var avesalary        "Average Salary of Full Time Workers"

lab var abortionRelatedNZ  "Inpatient Visits due to Abortion Related Complications (overnight)"

lab dat "Morbidity, Mortality and Fertility data: State by Year Aggregates"
save "$OUT/Demographics_YearXState.dta", replace

exit

********************************************************************************
*** (8) Monthly SAEH only
********************************************************************************
use "$DAT/Hospital/dta/SAEH_consolidate.dta", clear 
keep if sexo==2
gen cases = 1
drop if year<2000
drop if year==.
keep if edad>14 & edad<50

gen ICD_4 = substr(afecprin,1,4)
gen ICD_3 = substr(afecprin,1,3)
gen ICD_1 = substr(afecprin,1,1)

gen date = year+(mes-1)/12
keep if estado<=32
#delimit ;
gen abortionRelated = ICD_3=="O02"|ICD_3=="O03"|ICD_3=="O04"|ICD_3=="O05"|
                      ICD_3=="O06"|ICD_3=="O07"|ICD_3=="O08";
gen abortionRelatedNZ = abortionRelated==1&dias_esta!=0;
gen deliveries      = ICD_3=="O80"|ICD_3=="O81"|ICD_3=="O82"|ICD_3=="O83"|
                      ICD_3=="O84";
gen haemorrhage     = ICD_3=="O20";
gen O02             = ICD_3=="O02";
gen O03             = ICD_3=="O03";
gen O04             = ICD_3=="O04";
gen O05             = ICD_3=="O05";
gen O06             = ICD_3=="O06";
gen O07             = ICD_3=="O07";
gen O08             = ICD_3=="O08";
gen totalNonBirth   = deliveries!=1;
gen totalONonBirth  = ICD_1=="O"&deliveries!=1;
gen abortComplic    = abortionRelated;
replace abortComplic= 0 if ICD_4=="O034"|ICD_4=="O039"|ICD_4=="O044"|
                           ICD_4=="O049"|ICD_4=="O054"|ICD_4=="O059"|
                           ICD_4=="O064"|ICD_4=="O069"|ICD_4=="O074"|
                           ICD_4=="O079"|ICD_3=="O02";
gen abortNoComplic = abortionRelated;
replace abortNoComplic = 0 if abortComplic==1;
gen extraction = ICD_4=="Z303";
#delimit cr

local amorb abortionRelated abortionRelatedNZ abortNoComplic abortComplic O0* total*
local omorb deliveries haemorrhage extraction
local days
foreach var of varlist `amorb' `omorb' {
    gen days_`var' = dias_esta if `var'==1
    local days `days' days_`var'
}
collapse (sum) `amorb' `omorb' `days', by(date year estado) fast
tempfile mort
save `mort'

use "$POP/populationStateYear", clear
drop month
reshape long year_, i(stateName Age stateNum) j(Year)
rename year_ population
keep if Age>=15&Age<=44
collapse (sum) population, by(stateName stateNum Year)
rename Year year 
keep if year>=2000&year<=2015

#delimit ;
local snum 29 12 09 17 03 28 10 01 32 04 22 14 26 07 25 16 30 23 13 05 21 27
19 15 18 02 24 06 31 11 20 08;
#delimit cr
gen estado = .
local i = 1
foreach num in `snum' {
    replace estado = `i' if stateNum=="`num'"
    local ++i
}

merge 1:m year estado using `mort'
gen date12 = date*12
xtset estado date12


#delimit;
gen regressiveState=stateName=="BajaCalifornia"|stateName=="Chiapas"
|stateName=="Chihuahua"|stateName=="Colima"|stateName=="Durango"
|stateName=="Guanajuato"|stateName=="Jalisco"|stateName=="Morelos"
|stateName=="Nayarit"|stateName=="Oaxaca"|stateName=="Puebla"
|stateName=="Queretaro"|stateName=="QuintanaRoo"|stateName=="SanLuisPotosi"
|stateName=="Sonora"|stateName=="Tamaulipas"|stateName=="Yucatan"
|stateName=="Veracruz"|stateName=="Campeche";
#delimit cr

lab dat "Morbidity data: State by Month*Year Aggregates"
save "$OUT/morbidity/morbiditySAEH_month.dta", replace


********************************************************************************
*** (9) Clean up
********************************************************************************
log close

