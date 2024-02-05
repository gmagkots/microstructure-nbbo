/* ********************************************************************************* */
/*                                                                                   */
/* Macro   : debug                                                                   */
/* Summary : Auxiliary macro that prints the input data set with its contents.       */
/* Input   : A string that contains the data set name to print.                      */
/* Output  : ASCII output to the *.lst file (or the Output window).                  */
/*                                                                                   */
/* Author  : Georgios Magkotsios                                                     */
/* Created : July 2012                                                               */
/*                                                                                   */
/* ********************************************************************************* */

%macro debug(input_data);

    /* print the input data set along with its contents */
    proc contents data=&input_data;
    run;
    proc print data=&input_data;
    run;

%mend debug;
