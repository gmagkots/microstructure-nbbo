/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : plot_basic                                                              */
/* Summary : Creates a few basic plots for the output data.                          */
/* Input   : The trading date (in SAS format) and the main output data.              */
/* Output  : Various plots of the output data.                                       */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro plot_basic;

    /* get a few summary statistics prior to creating the plots */
    %summarize;

    /* specify the annotation text */
    %let FootnoteText = "Period: " 
        "%sysfunc(PutN(&StartDate,mmddyy10.)) - "
        "%sysfunc(PutN(&EndDate,mmddyy10.))";
    %let InsetText = "Time Lag: &LagSeconds. sec";

    /* set the line thickness value */
    %let linethickness = 3px;

    /* close all destinations, including the default ones */
    ods _all_ close;

    /* set the orientation to landscape for the graphs */
    options orientation=landscape;

    /* modify some properties within the printer template */
    proc template;
        define style CustomStyle;
        parent = styles.printer;
        style GraphFonts from GraphFonts /
            'GraphDataFont' = ("<MTserif>, <serif>",9pt)
            'GraphValueFont' = ("<MTserif>, <serif>",14pt,bold)
            'GraphLabelFont' = ("<MTserif>, <serif>",16pt,bold)
            'GraphFootnoteFont' = ("<MTserif>, <serif>",13pt,bold)
            'GraphTitleFont' = ("<sans-serif>, <MTsans-serif>",18pt,bold);
        style GraphAxisLines from GraphAxisLines /
            linethickness = &linethickness;
        style GraphWalls from GraphWalls /
            linethickness = &linethickness;
        style GraphOutlines from GraphOutlines /
            linethickness = &linethickness;
        style GraphFit from GraphFit /
            linethickness = &linethickness;
        style GraphFit2 from GraphFit2 /
            linethickness = &linethickness;
        style GraphDataDefault from GraphDataDefault /
            markersize    = 9px;
        end;
    run;

    /* create the annotation data set (good for SAS 9.3 only) */
/*
    data AnnotationData;
        function = "text";
        x1 = 5;
        y1 = 5;
        label = cat("Date: ",put(&StartDate,mmddyy10.),
                    " - "   ,put(&EndDate,mmddyy10.));
    run;
*/
    /* set the ods graphics options */
    ods graphics on /
        reset=all
        width=10.5in
        height=7.8in
        border=off;


    /* histograms */

    ods &OdsDestination style=CustomStyle BOOKMARKGEN=NO
        %if (&LagSeconds) %then %do;
            file="&PlotDir.frac_price_nbbo_hist_lag&LagSeconds._&OutputSuffix..pdf";
        %end;
        %else %do;
            file="&PlotDir.frac_price_nbbo_hist_&OutputSuffix..pdf";
        %end;
    proc sgplot data=ranked_NBBO
        /*(where=(&RankVariable between &RankValueMin and &RankValueMax))*/;
        histogram ImplicitPriceBin;
        *density ImplicitPriceBin / type=kernel;
        title "Implicit price fraction for all NBBO quotes";
        xaxis label = "Tick Fraction of Implicit Price";
        footnote j=r &FootnoteText;
        %if &LagSeconds > 0 %then inset &InsetText / noborder position=topleft;;
    run;
    ods &OdsDestination close;

    ods &OdsDestination style=CustomStyle BOOKMARKGEN=NO
        %if (&LagSeconds) %then %do;
            file="&PlotDir.frac_price_trades_hist_lag&LagSeconds._&OutputSuffix..pdf";
        %end;
        %else %do;
            file="&PlotDir.frac_price_trades_hist_&OutputSuffix..pdf";
        %end;
    proc sgplot data=ranked_trades
        /*(where=(&RankVariable between &RankValueMin and &RankValueMax))*/;
        histogram ImplicitPriceBin;
        *density ImplicitPriceBin;
        title "Implicit price fraction for all trades";
        xaxis label = "Tick Fraction of Implicit Price";
        footnote j=r &FootnoteText;
        %if &LagSeconds > 0 %then inset &InsetText / noborder position=topleft;;
    run;
    ods &OdsDestination close;

    /* scatter plots */

    ods &OdsDestination style=CustomStyle BOOKMARKGEN=NO
        %if (&LagSeconds) %then %do;
            file="&PlotDir.trade_indicator_lag&LagSeconds._&OutputSuffix..pdf";
        %end;
        %else %do;
            file="&PlotDir.trade_indicator_&OutputSuffix..pdf";
        %end;
    proc sgplot data=merge_means;
        *xaxis min=0 max=0.005;
        scatter x=MeanImplicitPriceModTrades y=MeanTradeIndicatorQ;
        title "Average Trade Indicator distribution";
        xaxis label = "Tick Fraction of Implicit Price";
        yaxis label = "Trade Indicator Q";
        footnote j=r &FootnoteText;
    run;
    ods &OdsDestination close;

    ods &OdsDestination style=CustomStyle BOOKMARKGEN=NO
        %if (&LagSeconds) %then %do;
            file="&PlotDir.trade_frequency_lag&LagSeconds._&OutputSuffix..pdf";
        %end;
        %else %do;
            file="&PlotDir.trade_frequency_&OutputSuffix..pdf";
        %end;
    proc sgplot data=merge_means;
        scatter x=MeanImplicitPriceModTrades y=FreqTrades;
        title "Trade frequency distribution";
        xaxis label = "Tick Fraction of Implicit Price";
        yaxis label = "Trade Frequency";
        footnote j=r &FootnoteText;
    run;
    ods &OdsDestination close;

    /* Close the graphics destination */
    ods graphics off;

%mend plot_basic;
