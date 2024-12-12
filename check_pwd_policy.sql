create or replace noneditionable function pwd_verify_function
 ( username     varchar2,
   password     varchar2,
   old_password varchar2)
 return boolean IS
   differ       integer;
   lang         varchar2(512);
   message      varchar2(512);
   ret          number;
   dbname       varchar2(20);
   l_cstr       varchar2(100);
   l_len        number;
   l_c          char(1);
   l_nstr       varchar2(100);
   l_ncount     number;


begin
   -- Get the cur context lang and use utl_lms for messages- Bug 22730089
   lang := sys_context('userenv','lang');
   lang := substr(lang,1,instr(lang,'_')-1);

   -- min 18 characters, 1 uppercase, 1 lower case, 1 digit, 1 special
   if not ora_complexity_check(password, chars => 18, uppercase => 1, lowercase => 1,
                           digit => 1, special => 1) then
      return(false);
   end if;

   -- Check if the password differs from the previous password by at least
   -- 8 characters
   if old_password is not null then
      differ := ora_string_distance(old_password, password);
      if differ < 8 then
         ret := utl_lms.get_message(28211, 'RDBMS', 'ORA', lang, message);
         raise_application_error(-20000, utl_lms.format_message(message, 'eight'));
      end if;
   end if;

   -- Check if the password is same as the username

   -- Check if password contains username
   IF INSTR( NLS_LOWER(password), NLS_LOWER(username) ) != 0 THEN
      raise_application_error(-20000, 'Password verification failed - password cannot contain username.');
   END IF;

   -- Check if password contains db name
   select name into dbname from v$database;
   IF INSTR( NLS_LOWER(password), NLS_LOWER(dbname) ) != 0 THEN
      raise_application_error(-20000, 'Password verification failed - password cannot contain db name.');
   END IF;

   -- Check each character does not repeate more than 4 times
   l_cstr := UPPER(password);
   l_len := LENGTH(l_cstr);
   WHILE l_len > 0 LOOP
   l_c := SUBSTR(l_cstr, 1, 1);
   l_nstr := REPLACE(l_cstr, l_c, NULL);
   l_ncount := LENGTH(l_cstr) - NVL(LENGTH(l_nstr),0);
   IF l_ncount > 0 AND l_c <> ' ' THEN
     IF l_ncount > 4 THEN
       raise_application_error(-20000, 'Password verification failed - password cannot contain one character more than 4 times.');
     END IF;
   END IF;
   l_len := LENGTH(l_nstr);
   l_cstr := l_nstr;
   END LOOP;

   return(true);
END;
