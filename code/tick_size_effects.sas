/* ********************************************************************************* */
/* ******************************* TICK SIZE EFFECTS ******************************* */
/* ********************************************************************************* */
/*                                                                                   */
/* Program : tick_size_effects                                                       */
/* Summary : Compares the reported trade data with the corresponding NBBO data for   */
/*           low-price stocks that trade on the tick, to determine evidence of       */
/*           rationality in markets with large ticks.                                */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

/*------------------  use this part if using SAS/Connect-----------------
  %let wrds = wrds.wharton.upenn.edu 4016;
  options comamid=TCP remote=WRDS;
  signon username=_prompt_;
  rsubmit;
---------------------------------------------------------------------- */

/* determine the system options */
options nodate nocenter nonumber nosource ps=max ls=max;
options sasautos = ('./macros', sasautos) mautosource;
/* options spool macrogen symbolgen mprint mprintnest mlogic; */

/* define the output directories */
libname LibLocal './data';
libname LibLarge '/scratch/usc/magkotsi';
%let PlotDir = ./plots/;

/* define and run the main driver macro */
%macro tick_size_effects;

    /* determine the main controls */
    %let CalculateNBBO   = 0;
    %let MergeNBBOTrades = 0;
    %let MakePlots       = 01;
    %let DebugMode       = 0;

    /* determine the input for data collection */
    %let StartTime   = '09:30:00't;
    %let EndTime     = '16:00:00't;
    %let InputSuffix = 2011110:;
    %let LagSeconds  = 0;

    /* set the start and end dates for the output file names */
    %let StartDate = %sysfunc(mdy(11,01,2011));
    %let EndDate   = %sysfunc(mdy(11,09,2011));

    /* hardwire a list of stocks for the moment */
    %let SymbolList = ('BAC', 'GRT', 'ISIS', 'NKTR', 'SGMS');

    /* set the number of bins that the fractional part
       of the implicit price will be distributed in */
    %let ImplicitPriceTotalBins = 20;

    /* determine the input for data plots */
    %let OdsDestination = pdf;
    %let RankVariable   = TotalLogSize;
    %let RankGroups     = 4;
    %let RankValueMin   = 0;
    %let RankValueMax   = 0;
    %let BestSizeThreshold = 100;

/* do not modify the lines below */

    /* output file names' suffix */
    %let OutputSuffix1 = %sysfunc(PutN(&StartDate,date9.));
    %let OutputSuffix2 = %sysfunc(PutN(&EndDate,date9.));
    %let OutputSuffix  = &OutputSuffix1._&OutputSuffix2;

    /* major data file names */
    %if (&LagSeconds) %then %do;
        %let DataNBBO = LibLocal.nbbo_lag&LagSeconds._&OutputSuffix;
        %let DataMain = LibLarge.trades_lag&LagSeconds._&OutputSuffix;
    %end;
    %else %do;
        %let DataNBBO = LibLocal.nbbo_&OutputSuffix;
        %let DataMain = LibLarge.trades_&OutputSuffix;
    %end;

    /* calculate the NBBO quotes from raw quotes in TAQ */
    %if (&CalculateNBBO) %then %calculate_nbbo;

    /* merge the TAQ trades with the NBBO quotes */
    %if (&MergeNBBOTrades) %then %merge_nbbo_trades;

    /* analyze the data */
    %if (&MakePlots) %then %plot_basic;

%mend tick_size_effects;

%tick_size_effects;

/*------------------  use this part if using SAS/Connect-----------------
  endrsubmit;
  signoff;
---------------------------------------------------------------------- */
