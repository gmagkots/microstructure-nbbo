/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : merge_nbbo_trades                                                       */
/* Summary : Determines the NBBO quotes for every second, and matches them with      */
/*           trades including a user-specified lag rule.                             */
/* Input   : 1) The trading date (in SAS date format),                               */
/*           2) the start and end times for trading activity (as SAS constants),     */
/*           3) the time lag between trade and quote time (in seconds),              */
/*           4) a list of the stock symbols to be considered, and                    */
/*           5) a logical to determine normal or debug running mode.                 */
/* Output  : A data set with the NBBO quotes and corresponding (lagged) trades.      */
/* Notes   : 1) Informat for exchanges                                               */
/*              The character label of an exchange is converted to a unique numeric  */
/*              identifier, to facilitate the calculation of NBBO using arrays.      */
/*           2) Declaration of certain variables                                     */
/*              The quote and trade symbols are initialized as strings (of length 10 */
/*              as in the TAQ data sets) to avoid numeric-to-character error by the  */
/*              comparison operator and "in" command during the data filtering. The  */
/*              date is initialized only to have it appear next to the symbol in the */
/*              output files. The bid/offer arrays and their corressponding sizes    */
/*              are declared to indicate the dimension of the arrays.                */
/*           3) Use of link statement                                                */
/*              The LINK statement (a GOTO programming logic) is used because the    */
/*              records have to be read by a single SET statement. Using a second    */
/*              SET statement on the same data set will either read the current      */
/*              record twice, or produce other type of logical errors.               */
/*           4) Separation of quote and trade symbols                                */
/*              The nested DOW loops for quotes and trades have to be independent,   */
/*              otherwise data-dependent mismatches may appear. Thus, the key SYMBOL */
/*              is split in two names to properly match quotes and trades, since the */
/*              numbers of unique symbols in TAQ quotes and trades for the same Date */
/*              are usually different.                                               */
/*           5) Time difference logic and illiquid stocks                            */
/*              The difference between trade and lagged quote time is used to match  */
/*              irregularly gridded records (e.g. a time interval with many quotes   */
/*              but without any trade, or missing quotes due to illiquid stock). It  */
/*              is possible that the time difference changes sign without reaching   */
/*              the value zero. The do loop should account for this case and         */
/*              continue reading the other file accordingly. As soon as a zero time  */
/*              difference between a trade and a lagged quote is found, the match is */
/*              considered successful and the code exits the loop. In case there is  */
/*              no successful match, the inequality operator will prevent reading    */
/*              the whole file without a subsequent match and it will allow only one */
/*              record match that will not satisfy the time lag criteria. The        */
/*              subsetting IF statement before the end of the data step ensures that */
/*              this record is not output to the data file.                          */
/*           6) The presence of return statements                                    */
/*              Each link label requires a return statement to return the control    */
/*              immediately after the LINK statement. The code enclosed by the link  */
/*              must be included in the DATA step, so an additional return statement */
/*              is added to indicate the point where SAS should consider as the end  */
/*              of the DATA step.                                                    */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro merge_nbbo_trades;

    /* create an informat to convert EX to numeric. The initial list (Rabih Moussawi)
       includes more exchanges than defined in TAQ manuals, but keep them anyway. */
    proc format;
        invalue ExToExn      /* informat to be used in an INPUT function */
            'A'=01   /*AMEX*/
            'N'=02   /*NYSE*/
            'B'=03   /*BOST*/
            'P'=04   /*ARCA*/
            'C'=05   /*NSX -National (Cincinnati) Stock Ex*/
            'T'=06   /*NASD*/
            'Q'=07   /*NASD*/
            'D'=08   /*NASD-ADF*/
            'X'=09   /*PHIL-NASDAQ OMX PSX*/
            'I'=10   /*ISE */
            'M'=11   /*CHIC*/
            'W'=12   /*CBOE*/
            'Z'=13   /*BATS*/
            'Y'=14   /*BATS Y-Ex*/
            'J'=15   /*DEAX-DirectEdge A*/
            'K'=16   /*DEXX-DirectEdge X*/
            otherwise=17;
    run;

    /* main data step for merging NBBO quotes with trades */
    data &DataMain
        (keep=Date TradeSymbol QuoteTime TradeTime BestBid BestOffer BestBidSize
              BestOfferSize TradePrice TradeSize ImplicitPrice ImplicitPriceDec);

        /* declare the symbol types to avoid defining them both as numeric and
           character, and initialize the date to appear after the symbol in
           the output files */
        QuoteSymbol = '          ';
        TradeSymbol = '          ';
        Date = &TradingDate;

        /* declare the arrays for each of the exchanges */
        array BidArray{16};
        array OfferArray{16};
        array BidSizeArray{16};
        array OfferSizeArray{16};

        /* find the NBBO quotes for a stock within a second */
        link Find_NBBO_InSecond;

        /* read the next trade within a second */
        link ReadTradeInSecond;

        /* match the symbols if necessary (usually after the last record
           for a symbol) */
        if QuoteSymbol < TradeSymbol then
            do until (QuoteSymbol >= TradeSymbol);
                link Find_NBBO_InSecond;
                if QuoteSymbol = TradeSymbol then leave;
            end;
        else if QuoteSymbol > TradeSymbol then
            do until (QuoteSymbol <= TradeSymbol);
                link ReadTradeInSecond;
                if QuoteSymbol = TradeSymbol then leave;
            end;

        /* define the time difference between quote and lagged trade */
        TimeDifference = TradeTime - (QuoteTime + &LagSeconds);

        /* match the times for a symbol by further data reading if necessary */
        if TimeDifference > 0 then
            /* trade time value is larger than expected, read more quotes */
            do until (TimeDifference <= 0);
                link Find_NBBO_InSecond;
                TimeDifference = TradeTime - (QuoteTime + &LagSeconds);
                if TimeDifference = 0 then leave;
            end;
        else if TimeDifference < 0 then
            /* quote time value is larger than expected, read more trades */
            do until (TimeDifference >= 0);
                link ReadTradeInSecond;
                TimeDifference = TradeTime - (QuoteTime + &LagSeconds);
                if TimeDifference = 0 then leave;
            end;

        /* accept only records that satisfy the time lag criteria */
        *if TimeDifference = 0;

        /* force implicit end point for DATA step here */
        return;

        /* link label for finding NBBO quote */
        Find_NBBO_InSecond:
            %find_nbbo;
        return;

        /* link label for reading trade data */
        ReadTradeInSecond:
            %read_trade;
        return;

        /* label all new variables */
        label BestBid = 'National Best Bid (NBBO bid)'
            BestOffer = 'National Best Offer (NBBO offer)'
            BestBidSize   = 'Aggregate size at NBBO bid'
            BestOfferSize = 'Aggregate size at NBBO offer'
            ImplicitPrice    = 'Security "true" price inferred by traders'
            ImplicitPriceDec = 'Decimal part of the inferred "true" price';

    run;

    /* print data details when in debugging mode */
    %if (&DebugMode) %then %do;
        proc contents data=&DataMain;
        run;

        proc print data=&DataMain;
            format Date mmddyy10.;
        run;
    %end;

%mend merge_nbbo_trades;
