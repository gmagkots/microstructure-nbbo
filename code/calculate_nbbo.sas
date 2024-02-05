/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : calculate_nbbo                                                          */
/* Summary : Calculates the NBBO quotes every second, and estimates the "real" price */
/*           as inferred by traders. For each exchange, only the last quote during a */
/*           second is considered. The sizes at NBBO are the aggregate sizes of all  */
/*           exchanges that quote at NBBO.                                           */
/* Controls: 1) The start and end times for trading activity (as SAS constants),     */
/*           2) the time lag between trade and quote time (in seconds),              */
/*           3) a list of the stock symbols to be considered, and                    */
/*           4) a logical to determine normal or debug running mode.                 */
/* Input   : The daily TAQ quote data sets.                                          */
/* Output  : The (lagged) NBBO data set.                                             */
/* Notes   : 1) Algorithm flow                                                       */
/*              The DOW loop scheme (SET statement inside a DO UNTIL loop) is used   */
/*              to read all quotes within the same second. As a result, each DATA    */
/*              step internal iteration corresponds to a unique combination of       */
/*              Date-Symbol-Time values, and the IF statement that guarantees the    */
/*              uniqueness of this combination may be omitted. This feature is       */
/*              expected to result in an additional performance increase.            */
/*           2) Informat for exchanges                                               */
/*              The character label of an exchange is converted to a unique numeric  */
/*              identifier, to facilitate the calculation of NBBO using arrays.      */
/*           3) ARRAY and RETAIN usage                                               */
/*              SAS ARRAYs are used to classify quote data according to the exchange */
/*              they originated from, and facilitate the calculation of the NBBO     */
/*              values. The RETAIN statement is necessary to avoid setting these     */
/*              variables to missing after each internal DATA step iteration.        */
/*           4) StartTime - EndTime interval                                         */
/*              A time interval is used to constrain the range of data inserted in   */
/*              the PDV with the WHERE= option in the SET statement. This is helpful */
/*              to properly match the starting and ending records between the NBBO   */
/*              and trade data when a time lag in included. It is necessary that the */
/*              specified time interval defines a subset of records for both the TAQ */
/*              quote and trade data, otherwise mismatches will appear. A reasonable */
/*              choice is to contrain the data during normal trading hours.          */
/*           5) Regularly gridded Time (fixed unit-step intervals)                   */
/*              Each record in TAQ quote files corresponds to a given quote by an    */
/*              exchange. It is possible that there are time intervals that no       */
/*              exchange updates its posted quotes (especially for illiquid stocks). */
/*              In order to create a regular grid for the Time variable, the latest  */
/*              NBBO values are replicated until there is an update to the NBBO.     */
/*           6) Time lag between quotes and trades                                   */
/*              A simple way to include a time lag between the quotes and trades     */
/*              (Lee & Ready, 1991) is to increase the Time value in the NBBO data   */
/*              by the user-specified lag value. The SET statement will interleave   */
/*              NBBO and trade data with the same Time value as it would without the */
/*              lag. However, the forward shift in Time of the NBBO data results in  */
/*              a match that is equivalent to combining current trades with lagged   */
/*              (past) NBBO values. The Time shift is performed every time the Time  */
/*              variable is initialized (begin of DATA step, and every first Symbol  */
/*              or Date. In addition, care is taken to properly match the lagged     */
/*              and regularly gridded Time with the QuoteTime in the TAQ data files. */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro calculate_nbbo;

    /* create an informat to convert EX to numeric. The initial list (Rabih Moussawi)
       includes more exchanges than defined in TAQ manuals, but keep them anyway. */
    proc format;
        invalue ExToExn      /* informat to be used in an INPUT function */
            'A'=01   /*AMEX*/
            'N'=02   /*NYSE*/
            'B'=03   /*BOST*/
            'P'=04   /*ARCA*/
            'C'=05   /*NSX - National (Cincinnati) Stock Ex*/
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

    /* create the NBBO data set */
    data &DataNBBO (keep=Date Symbol Time BestBid BestOffer BestBidSize BestOfferSize
                         TotalSize TotalLogSize MinBestSize
                         ImplicitPriceMod ImplicitPriceBin);

        /* initialize the date and symbol to force them appear first in the printed
           output files, define the regularly gridded time, and declare the arrays
           for each of the exchanges */
        if _N_ = 1 then do;
            Date   = today();
            Symbol = '          ';
            Time = &StartTime - 1 + &LagSeconds;
            array BidArray{17};
            array OfferArray{17};
            array BidSizeArray{17};
            array OfferSizeArray{17};
        end;

        /* retain variables */
        retain BidArray1-BidArray17
               OfferArray1-OfferArray17
               BidSizeArray1-BidSizeArray17
               OfferSizeArray1-OfferSizeArray17
               BestBid BestOffer BestBidSize BestOfferSize
               BestBidValid BestOfferValid BestBidSizeValid BestOfferSizeValid
               TotalSize TotalLogSize MinBestSize ImplicitPriceMod ImplicitPriceBin;

        /* read all the quotes during a second */
        do until (last.QuoteTime);
            /* data filtering conditions include:
                1 - choose a few select symbols only (temporary)
                2 - restrict during given trading time interval
                3 - sanity checks for bid, offer, sizes and spread
                4 - allow only NBBO eligible quotes (by mode value) */
            /* set LibLocal.taq_sample_quotes0: */
            set taq.cq_&InputSuffix
                (drop=mmid rename=(Time=QuoteTime)
                 where=(Symbol in &SymbolList and
                       (QuoteTime between &StartTime and &EndTime) and
                        bid > 0.01 and ofr > bid and
                        bidsiz > 0 and ofrsiz > 0 and
                       /* (ofr-bid) < 0.1*(ofr+bid) and */
                        mode in (1,2,6,10,12,23) ));
            by Date Symbol QuoteTime;

            /* reset the Time and nullify the arrays when a new symbol or new date
               are used */
            if first.Symbol or first.Date then do;
                Time = QuoteTime - 1 + &LagSeconds;
                do i=1 to 17;
                    BidArray(i)       = .;
                    OfferArray(i)     = .;
                    BidSizeArray(i)   = .;
                    OfferSizeArray(i) = .;
                end;
            end;

            /* convert EX to EXN for easy array reference */
            exn = input(ex,ExToExn.);

            /* store the quote info at the proper array elements. For each
               exchange, only the last quote during a second is considered. */
            BidArray(exn)       = bid;
            OfferArray(exn)     = ofr;
            BidSizeArray(exn)   = bidsiz;
            OfferSizeArray(exn) = ofrsiz;
        end;

        /* update the regularly gridded time */
        Time + 1;

        /* replicate the last NBBO when there are no quotes for a time period */
        do while (QuoteTime + &LagSeconds > Time);
            output;
            Time + 1;
        end;

        /* determine the NBBO values */
        BestBid   = max(of BidArray1-BidArray17);
        BestOffer = min(of OfferArray1-OfferArray17);

        /* aggregate sizes at NBBO */
        BestBidSize   = 0;
        BestOfferSize = 0;
        do i=1 to 17;
            if BidArray(i)   = BestBid   then BestBidSize   + BidSizeArray(i);
            if OfferArray(i) = BestOffer then BestOfferSize + OfferSizeArray(i);
        end;

        /* replace the cases of "locked market" (BestBid = BestOffer) and
           "crossed market" (BestBid > BestOffer) with last valid NBBO */
        if BestBid < BestOffer then do;
            BestBidValid = BestBid;
            BestOfferValid = BestOffer;
            BestBidSizeValid = BestBidSize;
            BestOfferSizeValid = BestOfferSize;
        end;
        else do;
            BestBid = BestBidValid;
            BestOffer = BestOfferValid;
            BestBidSize = BestBidSizeValid;
            BestOfferSize = BestOfferSizeValid;
            do i=1 to 17;
                BidArray(i)       = .;
                OfferArray(i)     = .;
                BidSizeArray(i)   = .;
                OfferSizeArray(i) = .;
            end;
        end;

        /* calculate the total size variables */
        TotalSize    = BestBidSize + BestOfferSize;
        TotalLogSize = log(BestBidSize) + log(BestOfferSize);
        MinBestSize  = min(BestBidSize,BestOfferSize);

        /* define the price that is inferred by traders, and keep the tick-size
           fractional part and its rounded value in a few bins within [0, 0.01] */
        ImplicitPriceMod = mod( (BestOffer*BestBidSize +
                                 BestBid*BestOfferSize) /
                                (BestBidSize + BestOfferSize) , 0.01);
        ImplicitPriceBin = round(ImplicitPriceMod, 0.01/&ImplicitPriceTotalBins);

        /* output to the data set */
        output;

        /* label all new variables */
        label Time = 'Regularly gridded time (in fixed time units)'
            BestBid = 'National Best Bid (NBBO bid)'
            BestOffer = 'National Best Offer (NBBO offer)'
            BestBidSize   = 'Aggregate size at NBBO bid'
            BestOfferSize = 'Aggregate size at NBBO offer'
            TotalSize     = 'Total size at NBBO (bid and offer sizes)'
            TotalLogSize  = 'Sum of log-sizes at NBBO'
            MinBestSize   = 'Minimum of best bid and best offer'
            ImplicitPriceMod = 'Tick fractional part of the price inferred by traders'
            ImplicitPriceBin = 'Binned tick fractional part (100 bins total)';

        /* specify the format for the regularly gridded time */
        format Time time.;
    run;

    /* print data details when in debugging mode */
    %if (&DebugMode) %then %debug(&DataNBBO);;

%mend calculate_nbbo;
