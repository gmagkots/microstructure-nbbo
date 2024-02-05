/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : plot_basic                                                              */
/* Summary : Creates a few basic plots for the output data.                          */
/* Input   : The trading date (in SAS format) and the main output data.              */
/* Output  : Various plots of the main output data.                                  */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : June 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro plot_basic;

    /* specify the annotation text */
    %let AnnotationText = "Date: %sysfunc(PutN(&TradingDate,mmddyy10.))";

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
        label = cat("Date: ",put(&TradingDate,mmddyy10.));
    run;
*/
    /* set the ods graphics options */
    ods graphics on /
        reset=all
        width=10.5in
        height=7.8in
        border=off;


    /* histograms */

    ods &OdsDestination style=CustomStyle
        file="&PlotDir.implicit_price_decimal_histogram.pdf";
    proc sgplot data=&DataMain;
        histogram ImplicitPriceDec;
        density ImplicitPriceDec;
        density ImplicitPriceDec / type=kernel;
        title "Inferred price (decimal part) histogram";
        footnote j=r &AnnotationText;
        /* inset &AnnotationText / noborder position=topright; */
    run;
    ods &OdsDestination close;


    /* scatter plots */

    ods &OdsDestination style=CustomStyle
        file="&PlotDir.implicit_price_decimal_trade_time.pdf";
    proc sgplot data=&DataMain;
        *xaxis min=0 max=10;
        scatter x=TradeTime y=ImplicitPriceDec / group=TradeSymbol;
        title "Inferred price (decimal part) vs Trade time";
        footnote j=r &AnnotationText;
    run;
    ods &OdsDestination close;

    /* matrix plot */
/*
    ods &OdsDestination style=CustomStyle
        file="&PlotDir.matrix_plot.pdf";
    proc sgscatter data=&DataMain;
        matrix ImplicitPrice TradePrice BestBid BestBidSize BestOffer BestOfferSize
            / diagonal=(histogram);
    run;
    ods &OdsDestination close;
*/

    /* Close the graphics destination */
    ods graphics off;

%mend plot_basic;
