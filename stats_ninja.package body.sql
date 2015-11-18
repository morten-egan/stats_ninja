create or replace package body stats_ninja

as

	function report_gs (
		counter_name						in				varchar2
	)
	return report_gs_list
	pipelined
	
	as
	
		l_ret_val			report_gs_rec;
	
	begin
	
		if sys_context('stats_ninja_c', counter_name) is null then
			l_ret_val.counter_name := counter_name;
			l_ret_val.statistic_name := 'No such counter';
			l_ret_val.statistic_num_val := -1;
			pipe row(l_ret_val);
		else
			l_ret_val.counter_name := counter_name;
			l_ret_val.statistic_name := 'Call count';
			l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name);
			pipe row(l_ret_val);
			if sys_context('stats_ninja_c', counter_name || '_ms_sum') is not null then
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Average calltime (ms)';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_ms_avg');
				pipe row(l_ret_val);
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Maximum calltime (ms)';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_ms_max');
				pipe row(l_ret_val);
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Minimum calltime (ms)';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_ms_min');
				pipe row(l_ret_val);
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Simple Moving Average (ms)';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_ms_sma_10');
				pipe row(l_ret_val);
			end if;
		end if;
	
		return;
	
		exception
			when others then
				raise;
	
	end report_gs;

	procedure gs (
		counter_name						in				varchar2
		, sample_rate						in				number default 0
	)
	
	as

		l_counter_value							number;
	
	begin

		if sys_context('stats_ninja_c', counter_name) is null then
			dbms_session.set_context('stats_ninja_c', counter_name, 1);
			if sample_rate = 0 then
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', 1);
			else
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
			end if;
		else
			l_counter_value := to_number(sys_context('stats_ninja_c', counter_name)) + 1;
			dbms_session.set_context('stats_ninja_c', counter_name, l_counter_value);
			if sample_rate <> 0 then
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
			end if;
		end if;
	
		exception
			when others then
				null;
	
	end gs;

	procedure gs (
		counter_name						in				varchar2
		, run_diff							in				interval day to second
		, sample_rate						in				number default 0
	)

	as

		l_counter_value							number;
		l_counter_ms							number;
		l_counter_ms_avg						number;
		l_counter_ms_max						number;
		l_counter_ms_min						number;
		l_counter_ms_sum						number;
		l_counter_ms_last_10					varchar2(4000);
		l_counter_ms_sma_10						number;

		cursor get_sma10(strin varchar2) is
			with t_data as (
                select regexp_substr(strin,'[^,]+', 1, level) as thenum from dual
                connect by regexp_substr(strin, '[^,]+', 1, level) is not null
			)
			select mvavg from (
			select
			  rnum
			  , thenum
			  , round(avg(thenum) over (order by rnum rows between 10 preceding and current row)) as mvavg
			from (
			  select
			    rownum as rnum
			    , thenum
			  from
			    t_data
			)
			order by rnum desc
			)
			where rownum = 1;

	begin

		if sys_context('stats_ninja_c', counter_name) is null then
			l_counter_ms := trunc(1000 * (extract(second from run_diff)
								+ 60 * (extract(minute from run_diff)
								+ 60 * (extract(hour from run_diff)
								+ 24 * (extract(day from run_diff) )))));
			dbms_session.set_context('stats_ninja_c', counter_name, '1');
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sum', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms);
			if sample_rate = 0 then
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', 1);
			else
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
			end if;
		elsif sys_context('stats_ninja_c', counter_name || '_ms_sum') is null then
			l_counter_ms := trunc(1000 * (extract(second from run_diff)
								+ 60 * (extract(minute from run_diff)
								+ 60 * (extract(hour from run_diff)
								+ 24 * (extract(day from run_diff) )))));
			l_counter_value := to_number(sys_context('stats_ninja_c', counter_name)) + 1;
			dbms_session.set_context('stats_ninja_c', counter_name, l_counter_value);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sum', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms);
			if sample_rate <> 0 then
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
			end if;
		else
			l_counter_value := to_number(sys_context('stats_ninja_c', counter_name)) + 1;
			dbms_session.set_context('stats_ninja_c', counter_name, l_counter_value);
			if mod(l_counter_value, to_number(sys_context('stats_ninja_c', counter_name || '_sample_rate'))) = 0 then
				l_counter_ms := trunc(1000 * (extract(second from run_diff)
								+ 60 * (extract(minute from run_diff)
								+ 60 * (extract(hour from run_diff)
								+ 24 * (extract(day from run_diff) )))));
				l_counter_ms_last_10 := sys_context('stats_ninja_c', counter_name || '_ms_last_10');
				if (length(l_counter_ms_last_10) - length(replace(l_counter_ms_last_10,','))) = 9 then
					l_counter_ms_last_10 := substr(l_counter_ms_last_10, instr(l_counter_ms_last_10, ',') + 1) || ',' || l_counter_ms;
				else
					l_counter_ms_last_10 := l_counter_ms_last_10 || ',' || l_counter_ms;
				end if;
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms_last_10);
				open get_sma10(l_counter_ms_last_10);
				fetch get_sma10 into l_counter_ms_sma_10;
				close get_sma10;
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms_sma_10);
				if sample_rate <> 0 then
					dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
				end if;
				if l_counter_ms > to_number(sys_context('stats_ninja_c', counter_name || '_ms_max')) then
					dbms_session.set_context('stats_ninja_c', counter_name || '_ms_max', l_counter_ms);
				end if;
				if l_counter_ms < to_number(sys_context('stats_ninja_c', counter_name || '_ms_min')) then
					dbms_session.set_context('stats_ninja_c', counter_name || '_ms_min', l_counter_ms);
				end if;
				l_counter_ms_sum := l_counter_ms + to_number(sys_context('stats_ninja_c', counter_name || '_ms_sum'));
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sum', l_counter_ms_sum);
				l_counter_ms_avg := round(l_counter_ms_sum/l_counter_ms);
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms_avg);
			end if;
		end if;

		exception
			when others then
				null;

	end gs;

end stats_ninja;
/