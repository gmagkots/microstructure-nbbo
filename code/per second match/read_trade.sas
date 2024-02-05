/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : read_trade                                                              */
/* Summary : Auxiliary macro that reads the last record during a second from a TAQ   */
/*           trade file.                                                             */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro read_trade;

    do until (last.TradeTime);
        /* data filtering conditions include:
            1 - choose a few select symbols only (temporary)
            2 - restrict during given trading time interval
            3 - sanity checks for trade price and size
            4 - allow only "good" trades (by correction value) */
        /* set DataDir.taq_sample_trades */
        set taq.ct_&InputSuffix
            (drop=g127 cond
             rename=(symbol=TradeSymbol time=TradeTime
                     price=TradePrice size=TradeSize)
             where=(TradeSymbol in &SymbolList and
                   (TradeTime between &StartTime + &LagSeconds and
                                      &EndTime) and
                    TradePrice > 0 and TradeSize > 0 and corr in (0 1 2) ));
        by Date TradeSymbol TradeTime;
    end;

%mend read_trade;
