create or replace package body stats_ninja

as

	procedure incr (
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
	
	end incr;

	procedure incr (
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

	begin

		if sys_context('stats_ninja_c', counter_name) is null then
			l_counter_ms := trunc(1000 * (extract(second from run_diff)
								+ 60 * (extract(minute from run_diff)
								+ 60 * (extract(hour from run_diff)
								+ 24 * (extract(day from run_diff) )))));
			dbms_session.set_context('stats_ninja_c', counter_name, '1');
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_sum', l_counter_ms);
			if sample_rate = 0 then
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', 1);
			else
				dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
			end if;
		elsif sys_context('stats_ninja_c', counter_name || 'ms_sum') is null then
			l_counter_ms := trunc(1000 * (extract(second from run_diff)
								+ 60 * (extract(minute from run_diff)
								+ 60 * (extract(hour from run_diff)
								+ 24 * (extract(day from run_diff) )))));
			l_counter_value := to_number(sys_context('stats_ninja_c', counter_name)) + 1;
			dbms_session.set_context('stats_ninja_c', counter_name, l_counter_value);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_avg', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_max', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_min', l_counter_ms);
			dbms_session.set_context('stats_ninja_c', counter_name || 'ms_sum', l_counter_ms);
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
				if sample_rate <> 0 then
					dbms_session.set_context('stats_ninja_c', counter_name || '_sample_rate', sample_rate);
				end if;
				if l_counter_ms > to_number(sys_context('stats_ninja_c', counter_name || 'ms_max')) then
					dbms_session.set_context('stats_ninja_c', counter_name || 'ms_max', l_counter_ms);
				end if;
				if l_counter_ms < to_number(sys_context('stats_ninja_c', counter_name || 'ms_min')) then
					dbms_session.set_context('stats_ninja_c', counter_name || 'ms_min', l_counter_ms);
				end if;
				l_counter_ms_sum := l_counter_ms + to_number(sys_context('stats_ninja_c', counter_name || 'ms_sum'));
				dbms_session.set_context('stats_ninja_c', counter_name || 'ms_sum', l_counter_ms_sum);
				l_counter_ms_avg := round(l_counter_ms_sum/l_counter_ms);
				dbms_session.set_context('stats_ninja_c', counter_name || 'ms_avg', l_counter_ms_avg);
			end if;
		end if;

		exception
			when others then
				null;

	end incr;

end stats_ninja;
/