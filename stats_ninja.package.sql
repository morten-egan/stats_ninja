create or replace package stats_ninja

as

	/** Implementation of a lightweight stats gathering framework for oracle
	* @author Morten Egan
	* @version 0.0.1
	* @project STATS_NINJA
	*/
	p_version		varchar2(50) := '0.0.1';

	type report_gs_rec is record (
		counter_name			varchar2(50)
		, statistic_name		varchar2(30)
		, statistic_num_val		number
	);
	type report_gs_list is table of report_gs_rec;

	/** Reporting table function for stat counters
	* @author Morten Egan
	* @param counter_name The name of the counter to report on
	* @return report_gs_list pipelined type
	*/
	function report_gs (
		counter_name						in				varchar2
	)
	return report_gs_list
	pipelined;

	/** Simple counter. Increment by one for the same counter
	* @author Morten Egan
	* @param counter_name The name of the counter we want to increment or create
	*/
	procedure gs (
		counter_name						in				varchar2
		, sample_rate						in				number default 0
	);

	/** Simple counter, including runtime stats
	* @author Morten Egan
	* @param counter_name The name of the counter we want to increment
	* @param run_diff The interval result of end timestamp minus begin timestamp
	*/
	procedure gs (
		counter_name						in				varchar2
		, run_diff							in				interval day to second
		, sample_rate						in				number default 0
	);

	/** Counter gs overload for extra functions, like Gauges, Histograms or Sets
	* @author Morten Egan
	* @param counter_name The name of the counter we want to either add to existing gauge or start gauge.
	* @param extra_name The name of the extra functionality to call
	* @param extra_value The value of the extra call
	*/
	procedure gs (
	  counter_name         		in				varchar2
		, extra_name						in				varchar2
		, extra_value						in				varchar2
	);

	/** Reset a counter back to zero
	* @author Morten Egan
	* @param counter_name The name of the counter to reset
	*/
	procedure clear (
		counter_name						in				varchar2
	);

end stats_ninja;
/
