/* ********************************************************************************* */
/* ******************************* TICK SIZE EFFECTS ******************************* */
/* ********************************************************************************* */
/*                                                                                   */
/* Program : tick_size_effects                                                       */
/* Summary : Compares the reported trade data with the corresponding quote data for  */
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
libname DataDir './data';
%let PlotDir = ./plots/;

/* define and run the main driver macro */
%macro tick_size_effects;

    /* determine the main controls */
    %let CollectData = 01;
    %let MakePlots   = 0;
    %let DebugMode   = 01;

    /* determine the input for data collection */
    %let TradingDate = %sysfunc(mdy(2,15,2008));
    %let StartTime   = '09:30:00't;
    %let EndTime     = '16:00:00't;
    %let LagSeconds  = 0;

    /* hardwire a list of stocks for the moment */
    %let SymbolList = ('BAC', 'GS', 'JPM');

    /* determine the input for data plots */
    %let OdsDestination = pdf;

/* do not modify the lines below */

    /* major data file name and suffixes */

    %let InputSuffix  = %sysfunc(PutN(&TradingDate,yymmddN8.));
    %let OutputSuffix = %sysfunc(PutN(&TradingDate,date9.));
    %let DataMain = DataDir.nbbo_trade_lag&LagSeconds._&OutputSuffix;

    /* merge the trade and quote data from TAQ (single day for the moment) */
    %if (&CollectData) %then %merge_nbbo_trades;

    /* analyze the data */
    %if (&MakePlots) %then %plot_basic;

%mend tick_size_effects;

%tick_size_effects;

/*------------------  use this part if using SAS/Connect-----------------
  endrsubmit;
  signoff;
---------------------------------------------------------------------- */
