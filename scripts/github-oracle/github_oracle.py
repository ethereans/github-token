import os, argparse
import json, urllib2, datetime
from collections import defaultdict
start = ''

script = os.environ['ARG0']
args = os.environ['ARG1']
auth = os.environ['ARG2']


if(auth):
    #check if is client secret or token




repo_link = ""
if(args):
    repo_link = "https://api.github.com/repos/" + args.reponame
else:
    repo_link = "https://api.github.com/repositories/" + args.repoid




if script == 'issue-status':
    issueStatus(args.issueid)
elif script == 'issue-commits':  
    issueCommits(args.issueid)
elif script == 'related-issues':
    relatedIssues(args.issueid) 
elif script == 'commit-points':
    pullCommitPoints(args.pullid)
elif script == 'commit-data':
    commitData(args.commit)







def relatedIssues(issue):
    link_issue = repo_link + "/issues/" + issue + "/timeline" + auth
    print link_issue
    req = urllib2.Request(link_issue)
    req.add_header("Accept", "application/vnd.github.mockingbird-preview")
    issue = json.load(urllib2.urlopen(req))
    for elem in issue:
        if(elem["event"] == "cross-referenced"):
            if(elem["source"]["type"] == "issue"):
                #print elem["source"]["issue"]["number"];
                pullCommitPoints(json.dumps(elem["source"]["issue"]["number"]))
   
    

def issueStatus(issue):
    link_issue = repo_link + "/issues/" + issue + auth
    issue = json.load(urllib2.urlopen(link_issue))
    if(issue['state'] == "closed"):
        print datetime.datetime.strptime( json.dumps(issue['closed_at'])[1:-1], "%Y-%m-%dT%H:%M:%SZ" ).strftime('%s') +","+ json.dumps(issue['closed_by']['login'])
    else:
        print "open"
    
    
def pullCommitPoints(pr):
    link_pull = repo_link + "/pulls/" + pr + auth
    pull = json.load(urllib2.urlopen(link_pull))
    if(pull['merged_at']):
        link_pulls_commits = repo_link + "/pulls/" + pr + "/commits" +auth
        points = defaultdict(int)
        commits = json.load(urllib2.urlopen(link_pulls_commits))
        for commit in commits:
            if(commit['url']):
                link_commit = json.dumps(commit['url'])[1:-1] +auth
                _commit = json.load(urllib2.urlopen(link_commit))
                author = json.dumps(_commit['author']['login'])[1:-1]
                points[author] += int(json.dumps(_commit['stats']['total']))
        print points.items()


def issueCommits(args.issueid):
    link_issue = repo_link + "/issues/" + issue + "/timeline" + auth
    req = urllib2.Request(link_issue)
    req.add_header("Accept", "application/vnd.github.mockingbird-preview")
    issue = json.load(urllib2.urlopen(req))
    for elem in issue:
        if(elem["event"] == "cross-referenced"):
            if(elem["source"]["type"] == "issue"):
                #print elem["source"]["issue"]["number"];
                pullCommitPoints(json.dumps(elem["source"]["issue"]["number"]))

def commitData(commit):
    link_commit = repo_link +"/commits/"+ commit;
    req = urllib2.Request(link_commit)
    req.add_header("Accept", "application/vnd.github.mockingbird-preview")
    commit = json.load(urllib2.urlopen(req))
    print json.dumps(commit)



