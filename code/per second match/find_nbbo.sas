/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : find_nbbo                                                               */
/* Summary : Auxiliary macro that finds the NBBO quotes within a second, and         */
/*           calculates the "real" price as realized by traders. For each exchange,  */
/*           only the last quote during a second is considered. The quote SYMBOL and */
/*           TIME variables are renamed to differentiate them from the corresponding */
/*           variables in the trade data file. The sizes at NBBO are the aggregate   */
/*           sizes of all exchanges that quote at NBBO.                              */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro find_nbbo;

    /* read all the quotes during a second */
    do until (last.QuoteTime);
        /* data filtering conditions include:
            1 - choose a few select symbols only (temporary)
            2 - restrict during given trading time interval
            3 - sanity checks for bid, offer, sizes and spread
            4 - allow only NBBO eligible quotes (by mode value) */
        /* set DataDir.taq_sample_quotes */
        set taq.cq_&InputSuffix
            (drop=mmid
             rename=(symbol=QuoteSymbol time=QuoteTime)
             where=(QuoteSymbol in &SymbolList and 
                   (QuoteTime between &StartTime and
                                      &EndTime - &LagSeconds) and
                    bid > 0.01 and ofr > bid and
                    bidsiz > 0 and ofrsiz > 0 and
                   (ofr-bid) < 0.1*(ofr+bid) and
                    mode in (1,2,6,10,12,23) ));
        by Date QuoteSymbol QuoteTime;

        /* nullify the arrays when a new symbol is used */
        if first.QuoteSymbol then
            do i=1 to 16;
                BidArray(i)       = .;
                OfferArray(i)     = .;
                BidSizeArray(i)   = .;
                OfferSizeArray(i) = .;
            end;

        /* convert EX to EXN for easy array reference and restrict
           exchanges within the given list */
        exn = input(ex,ExToExn.);
        if 1 <= exn <= 16;

        /* store the quote info at the proper array elements. For each
           exchange, only the last quote during a second is considered. */
        BidArray(exn)       = bid;
        OfferArray(exn)     = ofr;
        BidSizeArray(exn)   = bidsiz;
        OfferSizeArray(exn) = ofrsiz;
    end;

    /* determine the NBBO values */
    BestBid   = max(of BidArray1-BidArray16);
    BestOffer = min(of OfferArray1-OfferArray16);

    /* discard the cases of "locked market" (BestBid = BestOffer) and
       "crossed market" (BestBid > BestOffer) */
    if BestBid >= BestOffer then
        do i=1 to 16;
            BidArray(i)       = .;
            OfferArray(i)     = .;
            BidSizeArray(i)   = .;
            OfferSizeArray(i) = .;
        end;
    if BestBid < BestOffer;

    /* aggregate sizes at NBBO */
    BestBidSize   = 0;
    BestOfferSize = 0;
    do i=1 to 16;
        if BidArray(i)   = BestBid   then do;
            BestBidSize + BidSizeArray(i);
        end;
        if OfferArray(i) = BestOffer then do;
            BestOfferSize + OfferSizeArray(i);
        end;
    end;

    /* define "true" price that is inferred by traders, and its decimal part */
    ImplicitPrice    = (BestOffer*BestBidSize +
                        BestBid*BestOfferSize) /
                       (BestBidSize + BestOfferSize);
    ImplicitPriceDec = mod(ImplicitPrice,1);

%mend find_nbbo;
