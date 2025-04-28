#! /usr/bin/python

# -----------------------------------------------------------------------------------
# File Name    : check_db_session.py
# Author       : Duc Tran H
# Description  : Check session resource limit.
# Call Syntax  : check_db_sesion.py -w <warn threshold 0%-100%> -c <critical threshold 0-100%>
# Requirements : Access to the v$resource_limit.
# Last Modified: 02/Apr/2023
# -----------------------------------------------------------------------------------

#import modules
import sys, psutil, getopt, oracledb, db_config_sys

#nagios return codes
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3
usage = 'usage: ./check_db_session.py -w/--warn <integer> -c/--crit <integer>'

# check db session
def db_session(warn, crit):
    con = oracledb.connect(user=db_config_sys.sysuser, password=db_config_sys.syspw, dsn=db_config_sys.dsn)
    cur = con.cursor()
    sql = '''
    select round(CURRENT_UTILIZATION/LIMIT_VALUE*100,2) sessions_usage from v$resource_limit where resource_name = 'sessions'
    '''
    cur.execute(sql)
    res = cur.fetchall()
    res, = res[0]

    if res > crit:
        print("Critical - Current Database sesssion usage is:", res, "%")
        result = 1
        sys.exit(WARNING)
    elif res > warn:
        print("Warning - Current Database session usage is:", res, "%")
        result = 1
        sys.exit(CRITICAL)
    else:
        print("OK - Current Database session usage is:", res, "%")

# define command line options and validate data.  Show usage or provide info on required options
def command_line_validate(argv):
  try:
    opts, args = getopt.getopt(argv, 'w:c:o:', ['warn=' ,'crit='])
  except getopt.GetoptError:
    print(usage)
  try:
    for opt, arg in opts:
      if opt in ('-w', '--warn'):
        try:
          warn = int(arg)
        except:
          print('***warn value must be an integer***')
          sys.exit(CRITICAL)
      elif opt in ('-c', '--crit'):
        try:
          crit = int(arg)
        except:
          print('***crit value must be an integer***')
          sys.exit(CRITICAL)
      else:
        print(usage)
    try:
      isinstance(warn, int)
      #print 'warn level:', warn
    except:
      print('***warn level is required***')
      print(usage)
      sys.exit(CRITICAL)
    try:
      isinstance(crit, int)
      #print 'crit level:', crit
    except:
      print('***crit level is required***')
      print(usage)
      sys.exit(CRITICAL)
  except:
    sys.exit(CRITICAL)
  # confirm that warning level is less than critical level, alert and exit if check fails
  if warn > crit:
    print('***warning level must be less than critical level***')
    sys.exit(CRITICAL)
  return warn, crit

# main function
def main():
    argv = sys.argv[1:]
    warn, crit = command_line_validate(argv)
    db_session(warn, crit)

if __name__ == '__main__':
    main()
