create or replace package stats_ninja

as

	/** Implementation of a lightweight stats gathering framework for oracle
	* @author Morten Egan
	* @version 0.0.1
	* @project STATS_NINJA
	*/
	p_version		varchar2(50) := '0.0.1';

	/** Simple counter. Increment by one for the same counter
	* @author Morten Egan
	* @param counter_name The name of the counter we want to increment or create
	*/
	procedure incr (
		counter_name						in				varchar2
		, sample_rate						in				number default 0
	);

	/** Simple counter, including runtime stats
	* @author Morten Egan
	* @param counter_name The name of the counter we want to increment
	* @param run_diff The interval result of end timestamp minus begin timestamp
	*/
	procedure incr (
		counter_name						in				varchar2
		, run_diff							in				interval day to second
		, sample_rate						in				number default 0
	);

end stats_ninja;
/