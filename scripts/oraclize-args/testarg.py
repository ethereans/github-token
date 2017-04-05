import os, argparse
import json, urllib2, datetime
from collections import defaultdict
start = ''

parser = argparse.ArgumentParser()
parser.add_argument('-S','--script')

parser.add_argument('-U','--username')
parser.add_argument('-u','--userid')

parser.add_argument('-R','--repoid')
parser.add_argument('-r','--reponame')

parser.add_argument('-C','--commitid')

parser.add_argument('-B','--branch')
parser.add_argument('-T','--tail')
parser.add_argument('-H','--head')

parser.add_argument('-I','--issueid')
parser.add_argument('-P','--pullid')

parser.add_argument('-c','--client')
parser.add_argument('-s','--secret')


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

#branchname required





def updateCommits(branchname, head, tail):
    if(branchname is None):
        req = urllib2.Request(repo_link+auth)
        repo = json.load(urllib2.urlopen(req))
        branchname = json.dumps(repo['default_branch'])[1:-1]
    if(head is None and tail is not None): #tail only = error
        print "bad call"
        return
    elif(head is None and tail is None): #no head and no tail (new) = from latest head to reachable tails
        branches_link = repo_link + "/branches/" + branchname + auth
        req = urllib2.Request(branches_link)
        branch = json.load(urllib2.urlopen(req))
        _head = json.dumps(branch['commit']['sha'])[1:-1]
        head = _head
    elif(head is not None and tail is None): #head only (sync) = from latestHead to head  
        setClaimedChunk(head, "")
        branches_link = repo_link + "/branches/" + branchname + auth
        req = urllib2.Request(branches_link)
        branch = json.load(urllib2.urlopen(req))
        _head = json.dumps(branch['commit']['sha'])[1:-1]
        head = _head
    elif(tail is not None and head is not None): #head and tail (continue) = continue from tail
        _head = tail

    commit_link = repo_link + "/commits/" + _head + auth
    #print commit_link
    req = urllib2.Request(commit_link)
    _head = json.load(urllib2.urlopen(req))
    ntail = loadPoints(_head)

    print json.dumps(head) + "," + json.dumps(ntail['sha']) + ", ", 
    print str(len(points)) + ", ",
    print json.dumps(points.items()), 
 

#https://api.github.com/repos/status-im/github-oracle/compare/master...6e2528a9eb3fec21ca0679ec0c2a0935c2aa6656  COMPARE IF COMMIT IS IN `master`
#https://api.github.com/repos/status-im/github-oracle/commits?per_page=100&sha=e0a340e72784b1322929d6803773b31a2b6b5707
#https://api.github.com/repos/status-im/github-oracle/git/refs/heads BRANCHES
#https://developer.github.com/v3/#conditional-requests

def setCommittedTree(commit):
    if(claimed[commit['sha']] == False):
        claimed[commit['sha']] = True;
        for parent in commit['parents']:    
            link_commit = json.dumps(parent['url'])[1:-1] + auth
            _commit = json.load(urllib2.urlopen(link_commit))
            setCommittedTree(_commit);
            
            
def setClaimedChunk(head, tail):
    global count
    while (tail != head):
        commit_link = repo_link + "/commits" + auth + "&per_page=100&sha=" + head
        req = urllib2.Request(commit_link)
        commits = json.load(urllib2.urlopen(req));
        for commit in commits:
            if(claimed[commit['sha']] != True):
                claimed[commit['sha']] = True
                #print "claimed "+str(count)+": "+commit['sha']
                count += 1
                head = commit['sha']
                if(len(commit['parents']) == 2):
                    setClaimedChunk("", json.dumps(commit['parents'])[1][1:-1])
                if (tail == head): 
                    break
        if(len(commits) < 100):
            break
    return head

def loadPoints(head):
    global count

    while (claimed[head['sha']] == False and count < 1000):
        claimed[head['sha']] = True
        count += 1
        if (head['author'] is not None):
            author = json.dumps(head['author']['login'])[1:-1]
            if (len(points) > 5 and points[author] == 0): break;
            if (len(head['parents']) < 2):
                points[author] += int(json.dumps(head['stats']['total']))
                #print str(count) + ": " + head['sha'] +" +"+ str(head['stats']['total'])
            #else:
                #print str(count) + ": " + head['sha'] +" -"+ str(head['stats']['total'])
        #else:
            #print str(count) + ": " + head['sha'] +" x"+ str(head['stats']['total'])
        for parent in head['parents']:    
            link_commit = json.dumps(parent['url'])[1:-1] + auth
            _commit = json.load(urllib2.urlopen(link_commit))
            head = loadPoints(_commit)
    return head
    
        
    
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
    updateCommits(args.branch, args.head, args.tail)

