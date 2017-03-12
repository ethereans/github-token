import os, sys, json, urllib, datetime

print os.environ['ARG0']

if(len(sys.argv) < 3):
    print "too few arguments"
    sys.exit()

repo = sys.argv[1]
issue = sys.argv[2]
if(len(sys.argv) < 5):
    auth = ""
else:
    client_id = sys.argv[3]
    client_secret = sys.argv[4]
    auth = "?client_id="+client_id+"&client_secret="+client_secret

link_issue = "https://api.github.com/repos/" + repo + "/issues/" + issue + auth
issue = json.load(urllib.urlopen(link_issue))

if(issue['state'] == "closed"):
    print datetime.datetime.strptime( json.dumps(issue['closed_at'])[1:-1], "%Y-%m-%dT%H:%M:%SZ" ).strftime('%s') +","+ json.dumps(issue['closed_by']['login'])
else:
    print "open"