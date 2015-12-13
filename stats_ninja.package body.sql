create or replace package body stats_ninja

as

	procedure handle_histogram (
		counter_name							in				varchar2
	  , histogram_val           in        number
	)

	as

		cursor histograms(buckets varchar2) is
			select
				regexp_substr(buckets,'[^,]+', 1, level) as thenum
			from
				dual
			connect by
				regexp_substr(buckets, '[^,]+', 1, level) is not null;

		l_current_value						number;

	begin

	  for bucket in histograms(sys_context('stats_ninja_c', counter_name || '_buckets')) loop
			if histogram_val <= to_number(bucket.thenum) then
				l_current_value := to_number(sys_context('stats_ninja_c', counter_name || '_b_' || bucket.thenum)) + 1;
				dbms_session.set_context('stats_ninja_c', counter_name || '_b_' || bucket.thenum, l_current_value);
				exit;
			end if;
		end loop;

	  exception
	    when others then
	      raise;

	end handle_histogram;

	function report_gs (
		counter_name						in				varchar2
	)
	return report_gs_list
	pipelined

	as

		l_ret_val			report_gs_rec;

		cursor histograms(buckets varchar2) is
			select
				regexp_substr(buckets,'[^,]+', 1, level) as thenum
			from
				dual
			connect by
				regexp_substr(buckets, '[^,]+', 1, level) is not null;

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
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Exp Moving Average (ms)';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_ms_ema_10');
				pipe row(l_ret_val);
			end if;
			if sys_context('stats_ninja_c', counter_name || '_gauge') is not null then
				l_ret_val.counter_name := counter_name;
				l_ret_val.statistic_name := 'Counter gauge';
				l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_gauge');
				pipe row(l_ret_val);
			end if;
			if sys_context('stats_ninja_c', counter_name || '_buckets') is not null then
				for bucket in histograms(sys_context('stats_ninja_c', counter_name || '_buckets')) loop
					l_ret_val.counter_name := counter_name;
					l_ret_val.statistic_name := 'Value histogram (<= ' || bucket.thenum || ')';
					l_ret_val.statistic_num_val := sys_context('stats_ninja_c', counter_name || '_b_' || bucket.thenum);
					pipe row(l_ret_val);
				end loop;
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
		l_counter_ms								number;
		l_counter_ms_count					number;
		l_counter_ms_avg						number;
		l_counter_ms_max						number;
		l_counter_ms_min						number;
		l_counter_ms_sum						number;
		l_counter_ms_last_10				varchar2(4000);
		l_counter_ms_sma_10					number;
		l_counter_ms_ema_10					number;
		l_can_ema										boolean := false;
		l_gauge											number;

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
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_count', 1);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sum', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_ema_10', 0);
			if sys_context('stats_ninja_c', counter_name || '_gauge') is not null then
				l_gauge := to_number(sys_context('stats_ninja_c', counter_name || '_gauge')) + to_number(l_counter_ms);
				dbms_session.set_context('stats_ninja_c', counter_name || '_gauge', 0);
			end if;
			if sys_context('stats_ninja_c', counter_name || '_buckets') is not null then
				handle_histogram(counter_name, l_counter_ms);
			end if;
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
			l_counter_ms_count := 1;
			dbms_session.set_context('stats_ninja_c', counter_name, l_counter_value);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_count', l_counter_ms_count);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sum', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || '_ms_ema_10', 0);
			if sys_context('stats_ninja_c', counter_name || '_gauge') is not null then
				l_gauge := to_number(sys_context('stats_ninja_c', counter_name || '_gauge')) + to_number(l_counter_ms);
				dbms_session.set_context('stats_ninja_c', counter_name || '_gauge', 0);
			end if;
			if sys_context('stats_ninja_c', counter_name || '_buckets') is not null then
				handle_histogram(counter_name, l_counter_ms);
			end if;
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
				l_counter_ms_count := to_number(sys_context('stats_ninja_c', counter_name || '_ms_count')) + 1;
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_count', l_counter_ms_count);
				l_counter_ms_last_10 := sys_context('stats_ninja_c', counter_name || '_ms_last_10');
				if (length(l_counter_ms_last_10) - length(replace(l_counter_ms_last_10,','))) = 9 then
					l_counter_ms_last_10 := substr(l_counter_ms_last_10, instr(l_counter_ms_last_10, ',') + 1) || ',' || l_counter_ms;
					l_can_ema := true;
				else
					l_counter_ms_last_10 := l_counter_ms_last_10 || ',' || l_counter_ms;
				end if;
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_last_10', l_counter_ms_last_10);
				open get_sma10(l_counter_ms_last_10);
				fetch get_sma10 into l_counter_ms_sma_10;
				close get_sma10;
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_sma_10', l_counter_ms_sma_10);
				l_counter_ms_ema_10 := to_number(sys_context('stats_ninja_c', counter_name || '_ms_ema_10'));
				if l_counter_ms_ema_10 = 0 and l_can_ema then
					l_counter_ms_ema_10 := round((l_counter_ms - l_counter_ms_sma_10) * 0.1818 + l_counter_ms_sma_10);
					dbms_session.set_context('stats_ninja_c', counter_name || '_ms_ema_10', l_counter_ms_ema_10);
				elsif l_can_ema then
					l_counter_ms_ema_10 := round((l_counter_ms - l_counter_ms_ema_10) * 0.1818 + l_counter_ms_ema_10);
					dbms_session.set_context('stats_ninja_c', counter_name || '_ms_ema_10', l_counter_ms_ema_10);
				end if;
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
				l_counter_ms_avg := round(l_counter_ms_sum/l_counter_ms_count);
				dbms_session.set_context('stats_ninja_c', counter_name || '_ms_avg', l_counter_ms_avg);
				if sys_context('stats_ninja_c', counter_name || '_gauge') is not null then
					l_gauge := to_number(sys_context('stats_ninja_c', counter_name || '_gauge')) + to_number(l_counter_ms);
					dbms_session.set_context('stats_ninja_c', counter_name || '_gauge', 0);
				end if;
				if sys_context('stats_ninja_c', counter_name || '_buckets') is not null then
					handle_histogram(counter_name, l_counter_ms);
				end if;
				if sample_rate <> 0 then
					dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
				end if;
			end if;
		end if;

		exception
			when others then
				null;

	end gs;

	procedure gs (
		counter_name         		in				varchar2
		, extra_name						in				varchar2
		, extra_value						in				varchar2
	)

	as

		cursor conf_hist is
			select
				regexp_substr(extra_value,'[^,]+', 1, level) as thenum
			from
				dual
			connect by
				regexp_substr(extra_value, '[^,]+', 1, level) is not null;

	begin

		if extra_name = 'g' then
			dbms_session.set_context('stats_ninja_c', counter_name || '_gauge', 0);
		elsif extra_name = 'hc' then
			dbms_session.set_context('stats_ninja_c', counter_name || '_buckets', extra_value);
			for bucket in conf_hist loop
				dbms_session.set_context('stats_ninja_c', counter_name || '_b_' || bucket.thenum, 0);
			end loop;
		end if;

	  exception
	    when others then
	      raise;

	end gs;

	procedure reset (
		counter_name						in				varchar2
	)

	as

		cursor histograms(buckets varchar2) is
			select
				regexp_substr(buckets,'[^,]+', 1, level) as thenum
			from
				dual
			connect by
				regexp_substr(buckets, '[^,]+', 1, level) is not null;

	begin

		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name);
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_count');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_avg');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_max');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_min');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_sum');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_last_10');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_sma_10');
		dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_ms_ema_10');
		if sys_context('stats_ninja_c', counter_name || '_buckets') is not null then
			for bucket in histograms(sys_context('stats_ninja_c', counter_name || '_buckets')) loop
				dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_b_' || bucket.thenum);
			end loop;
			dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_buckets');
		end if;
		if sys_context('stats_ninja_c', counter_name || '_gauge') is  not null then
			dbms_session.clear_context(namespace => 'stats_ninja_c', attribute => counter_name || '_gauge');
		end if;

		exception
			when others then
				raise;

	end reset;

	procedure clear (
		counter_name						in				varchar2
	)

	as

	begin

		reset(counter_name);

		exception
			when others then
				raise;

	end clear;

end stats_ninja;
/
