/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : merge_nbbo_trades                                                       */
/* Summary : Matches the NBBO data with the corresponding trade data (interleaving)  */
/*           within a given time interval, including a user-specified lag rule.      */
/* Controls: 1) The start and end times for trading activity (as SAS constants),     */
/*           2) the time lag between trade and quote time (in seconds),              */
/*           3) a list of the stock symbols to be considered, and                    */
/*           4) a logical to determine normal or debug running mode.                 */
/* Input   : The (lagged) NBBO data set and the daily TAQ trade data sets.           */
/* Output  : A data set with the NBBO quotes and (lagged) trades merged.             */
/* Notes   : 1) Initialization of certain variables                                  */
/*              The Date, Symbol, and Time variables are initialized to force them   */
/*              appear first in the output files. Removing these statements won't    */
/*              have any consequences to the calculations.                           */
/*           2) Renaming and retaining the variables from the NBBO data file         */
/*              All variables in the NBBO quotes data that are not used in the BY    */
/*              statement are renamed, so that they may be retained and properly     */
/*              merged with the trade data. SAS does not retain variables that are   */
/*              read during interleaving. As a result, these variables are redefined */
/*              so that they may be retained, and then they are renamed in the DATA  */
/*              statement back to their original names.                              */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro merge_nbbo_trades;

    /* main data step for merging NBBO quotes with trades */
    data &DataMain (drop=BestBidIn BestOfferIn BestBidSizeIn BestOfferSizeIn
                         TotalSizeIn TotalLogSizeIn MinBestSizeIn
                         ImplicitPriceModIn ImplicitPriceBinIn corr);

        /* initialize the date, symbol, and time to force them appear first in the
           printed output files */
        Date   = today();
        Symbol = '          ';
        Time   = &StartTime;

        /* retain the temporary defined variables */
        retain
            BestBid
            BestOffer
            BestBidSize
            BestOfferSize
            TotalSize
            TotalLogSize
            MinBestSize
            ImplicitPriceMod
            ImplicitPriceBin;

        /* trade filtering conditions include:
            1 - choose a few select symbols only (temporary)
            2 - restrict during given trading time interval
            3 - sanity checks for trade price and size
            4 - allow only "good" trades (by correction value) */
        /* set LibLocal.taq_sample_trades0: */
        set &DataNBBO
                (rename=(BestBid=BestBidIn BestOffer=BestOfferIn
                         BestBidSize=BestBidSizeIn BestOfferSize=BestOfferSizeIn
                         TotalSize=TotalSizeIn
                         TotalLogSize=TotalLogSizeIn
                         MinBestSize=MinBestSizeIn
                         ImplicitPriceMod=ImplicitPriceModIn
                         ImplicitPriceBin=ImplicitPriceBinIn)
                 in=InNBBO)
            taq.ct_&InputSuffix
                (in=InTrades drop=g127 cond
                 where=(Symbol in &SymbolList and
                       (Time between &StartTime + &LagSeconds and &EndTime) and
                        Price > 0 and Size > 0 and corr in (0 1 2) ));
        by Date Symbol Time;

        /* define temporary variables to retain the NBBO data */
        if InNBBO then do;
            BestBid          = BestBidIn;
            BestOffer        = BestOfferIn;
            BestBidSize      = BestBidSizeIn;
            BestOfferSize    = BestOfferSizeIn;
            TotalSize        = TotalSizeIn;
            TotalLogSize     = TotalLogSizeIn;
            MinBestSize      = MinBestSizeIn;
            ImplicitPriceMod = ImplicitPriceModIn;
            ImplicitPriceBin = ImplicitPriceBinIn;
        end;

        /* calculate the proximity of the trade price to the best bid or best ask,
           and output the data when there is a trade */
        if InTrades and BestBid <= Price <= BestOffer then do;
            TradeIndicatorQ = (2*Price - (BestOffer + BestBid))/
                              (BestOffer - BestBid);
            output;
        end;

        /* label the temporary variables similarly to the input NBBO data, and
           re-label the Date and Time to appear as trade properties */
        label
            Date = 'Trade Date'
            Time = 'Trade Time'
            BestBid = 'National Best Bid (NBBO bid)'
            BestOffer = 'National Best Offer (NBBO offer)'
            BestBidSize   = 'Aggregate size at NBBO bid'
            BestOfferSize = 'Aggregate size at NBBO offer'
            TotalSize     = 'Total size at NBBO (bid and offer sizes)'
            TotalLogSize  = 'Sum of log-sizes at NBBO'
            MinBestSize   = 'Minimum of best bid and best offer'
            ImplicitPriceMod = 'Tick fractional part of the price inferred by traders'
            ImplicitPriceBin = 'Binned tick fractional part (100 bins total)'
            TradeIndicatorQ  = 'Proximity of trade price to best bid or best ask';

    run;

    /* print data details when in debugging mode */
    %if (&DebugMode) %then %debug(&DataMain);;

%mend merge_nbbo_trades;
