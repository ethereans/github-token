import os, argparse
import json, urllib2, datetime
from collections import defaultdict
start = ''


parser = argparse.ArgumentParser()
parser.add_argument('--client')
parser.add_argument('--secret')
parser.add_argument('--script')
parser.add_argument('--username')
parser.add_argument('--userid')
parser.add_argument('--repoid')
parser.add_argument('--reponame')
parser.add_argument('--issueid')
parser.add_argument('--pullid')
parser.add_argument('--commitid')


argn = []
try:
    for x in range(0, int(os.environ['ARGN'])):
        argn[x] = os.environ['ARG'+`x`]
    args = parser.parse_args(argn);
except KeyError:
    args = parser.parse_args()
                            
if(args.client is not None and args.secret is not None):
    client_id = args.client
    client_secret = args.secret
    auth = "?client_id="+client_id+"&client_secret="+client_secret                            
else:
    auth = ""
count = 0
repo_link = ""
if(args.reponame is not None):
    repo_link = "https://api.github.com/repos/" + args.reponame
else:
    repo_link = "https://api.github.com/repositories/" + args.repoid


points = defaultdict(int)      
claimed = defaultdict(bool)   

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
                #print _commit['sha'], 
                author = json.dumps(_commit['author']['login'])[1:-1]
                points[author] += int(json.dumps(_commit['stats']['total']))
        print points.items(), 


def issueCommits(issueid):
    link_issue = repo_link + "/issues/" + issueid + "/timeline" + auth
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



def updateIssue(issueid):
    link_issue = repo_link + "/issues/" + issueid + auth
    issue = json.load(urllib2.urlopen(link_issue))
    print issue['state'] + ", " + datetime.datetime.strptime( json.dumps(issue['closed_at'])[1:-1], "%Y-%m-%dT%H:%M:%SZ" ).strftime('%s') + ", ", 
    
    link_issue = repo_link + "/issues/" + issueid + "/timeline" + auth
    req = urllib2.Request(link_issue)
    req.add_header("Accept", "application/vnd.github.mockingbird-preview")
    issue = json.load(urllib2.urlopen(req))
    
    for elem in issue:
        if(elem["event"] == "cross-referenced"):
            if(elem["source"]["type"] == "issue"):
                #print elem["source"]["issue"]["number"];
                pr = json.dumps(elem["source"]["issue"]["number"])
                link_pull = repo_link + "/pulls/" + pr + auth
                pull = json.load(urllib2.urlopen(link_pull))
                if(pull['merged_at']):
                    link_pulls_commits = repo_link + "/pulls/" + pr + "/commits" +auth
                    commits = json.load(urllib2.urlopen(link_pulls_commits))
                    for commit in commits:
                        if(commit['url']):
                            link_commit = json.dumps(commit['url'])[1:-1] + auth
                            _commit = json.load(urllib2.urlopen(link_commit))
                            author = int(json.dumps(_commit['author']['id'])[1:-1])
                            points[author] += int(json.dumps(_commit['stats']['total']))
    print points.items() 


def updateCommits(branchname, lastcommit):
    if(len(lastcommit) > 0):
        commit_link = repo_link + "/commits/" + lastcommit + auth
        req = urllib2.Request(commit_link)
        commit = json.load(urllib2.urlopen(req));
        setCommittedTree(commit)
    
    branches_link = repo_link + "/branches/" + branchname + auth
    req = urllib2.Request(branches_link)
    branch = json.load(urllib2.urlopen(req));
    #print branch
    
    commit_link = repo_link + "/commits/" + branch['commit']['sha'] + auth
    req = urllib2.Request(commit_link)
    commit = json.load(urllib2.urlopen(req));
    loadPoints(commit)
    print points.items();
  

def setCommittedTree(commit):
    if(claimed[commit['sha']] == False):
        claimed[commit['sha']] = True;
        for parent in commit['parents']:    
            link_commit = json.dumps(parent['url'])[1:-1] + auth
            _commit = json.load(urllib2.urlopen(link_commit))
            setCommittedTree(_commit);


def loadPoints(commit):
    global count

    while (claimed[commit['sha']] == False):
        claimed[commit['sha']] = True
        if (len(commit['parents']) < 2 and commit['author'] is not None):
            author = json.dumps(commit['author']['login'])[1:-1]
            points[author] += int(json.dumps(commit['stats']['total']))
            print str(count) + ": " + commit['sha'] +" +"+ str(commit['stats']['total'])
            count += 1
            if (len(commit['parents']) == 1):
                link_commit = json.dumps(commit['parents'][0]['url'])[1:-1] + auth
                commit = json.load(urllib2.urlopen(link_commit))
        else:
            print str(count) + ": " + commit['sha'] +" -"+ str(commit['stats']['total'])
            count += 1
            for parent in commit['parents']:    
                link_commit = json.dumps(parent['url'])[1:-1] + auth
                _commit = json.load(urllib2.urlopen(link_commit))
                loadPoints(_commit)
    
        
    
if args.script == 'issue-status':
    issueStatus(args.issueid)
elif args.script == 'issue-update':  
    updateIssue(args.issueid)
elif args.script == 'issue-commits':  
    issueCommits(args.issueid)
elif args.script == 'related-issues':
    relatedIssues(args.issueid)
elif args.script == 'commit-points':
    pullCommitPoints(args.pullid)
elif args.script == 'commit-data':
    commitData(args.commitid)
elif args.script== 'update-commits':
    updateCommits("master", "")

