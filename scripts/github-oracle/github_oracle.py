import sys, os, argparse
import json, urllib2, datetime
from collections import defaultdict
start = ''
try:
    argn = int(os.environ['ARGN'])
except KeyError:
    sys.exit("400 Error") #bad call
if argn < 2:
    sys.exit("404 Error") #no default function


def oAuth(client, secret, code):
    # POST https://github.com/login/oauth/access_token
    # { "Accept": "application/json", "client_id" : client, "client_secret" : secret, "code": code }
    # RESPONSE {"access_token":"e72e16c7e42f292c6912e7710c838347ae178b4a", "scope":"repo,gist", "token_type":"bearer"}
    sys.exit("501 Not implemented")

#global
points = defaultdict(int)
claimed = defaultdict(bool)
count = 0
repo_link = ""

#load credentials
auth = 0
if argn > 2:
    auth = [x.strip() for x in os.environ['ARG2'].split(',')]
    if len(auth) == 3: #is token
        client = auth[0]
        secret = auth[1]
        code = auth[2]
        oAuth(client, secret, code)
        auth = 2
    elif len(auth) == 2: #is secret
        client = auth[0]
        secret = auth[1]
        auth = 1
    else:
        auth = 0

args = os.environ['ARG1']

def requestAPI(api_link, arguments_get=None, arguments_post=None):
    if arguments_get is None:
        arguments_get = []
    if auth == 1:
        arguments_get += [["client_id", client], ["client_secret", secret]]
    #if(auth == 2):
    #    arguments_post += [["Access-Token",token]]

    if len(arguments_get) > 0:
        api_link += "?"
        for argument in arguments_get:
            api_link += argument[0]+"="+argument[1]+"&"
        api_link = api_link[0:-1]
    #print api_link
    req = urllib2.Request(api_link)
    if arguments_post is not None and len(arguments_post) > 0:
        for argument in arguments_post:
            req.add_header(argument[0], argument[1])
    return urllib2.urlopen(req)

def getRepositoryURL(repository, name=True):
    global repo_link
    if name:
        repo_link = "https://api.github.com/repos/"
    else:
        repo_link = "https://api.github.com/repositories/"
    return repo_link + repository


def repositoryAdd(full_name):
    repository = json.load(requestAPI(getRepositoryURL(full_name)))
    print "["+json.dumps(repository['id'])+",",
    print json.dumps(repository['full_name'])+",",
    print json.dumps(repository['watchers_count'])+",",
    print json.dumps(repository['stargazers_count'])+"]"
    sys.exit()

def updateCommits(full_name, branch_name, head, tail):
    global repo_link
    repo_link = getRepositoryURL(full_name)
    if branch_name is None:
        repo = json.load(requestAPI(repo_link))
        branch_name = json.dumps(repo['default_branch'])[1:-1]
    if head is None and tail is not None: # error
        sys.exit("400 Error")
    elif head is None and tail is None: #(new) = from latest head to reachable tail
        branches_link = repo_link + "/branches/" + branch_name
        branch = json.load(requestAPI(branches_link))
        _head = json.dumps(branch['commit']['sha'])[1:-1]
        nhead = _head
    elif head is not None and tail is None: #head only (sync) = from latestHead to head
        ntail = setClaimedChunk(head, "")
        branches_link = repo_link + "/branches/" + branch_name
        branch = json.load(requestAPI(branches_link))
        _head = json.dumps(branch['commit']['sha'])[1:-1]
        nhead = _head
    elif tail is not None and head is not None: #head and tail (continue) = continue from tail
        ntail = setClaimedChunk(head, tail)
        _head = tail
        nhead = head

    ntail2 = loadPoints(_head)
    if head is None and tail is None:
        ntail = ntail2
    print json.dumps(nhead) + "," + json.dumps(ntail) + ", ",
    print str(len(points)) + ", ",
    print json.dumps(points.items()),

def setClaimedChunk(head, tail):
    global repo_link
    global count
    global claimed

    while tail != head:
        commit_link = repo_link + "/commits"
        commits = json.load(requestAPI(commit_link, [['per_page', '100'], ["sha", head]]))
        for commit in commits:
            if claimed[commit['sha']] != True:
                claimed[commit['sha']] = True
                print "claimed "+str(count)+": "+commit['sha']
                count += 1
                head = commit['sha']
                if len(commit['parents']) == 2:
                    setClaimedChunk("", json.dumps(commit['parents'])[1][1:-1])
                if tail == head:
                    break
        if len(commits) < 100:
            break
    return head

def loadPoints(head, upoints=True):
    global repo_link
    global count
    global claimed
    global points
    while tail != head:
        commit_link = repo_link + "/commits"
        commits = json.load(requestAPI(commit_link, [['per_page', '100'], ["sha", head]]))
        for commit in commits:
            if claimed[commit['sha']] != True:
                claimed[commit['sha']] = True
                print "claimed "+str(count)+": "+commit['sha']
                count += 1
                head = commit['sha']
                if len(commit['parents']) == 1 and commit['author'] is not None:
                    if len(points) > 5 and points[author] == 0:
                        break
                    commit = json.load(requestAPI(commit['url']))
                    author = json.dumps(commit['author']['login'])[1:-1]
                    points[author] += int(commit['stats']['total'])
        if len(commits) < 100:
            break
    return head

script = os.environ['ARG0']
args = [x.strip() for x in os.environ['ARG1'].split(',')]

if script == 'repo-update':
    full_name = args[0]
    branch_name = None
    head = None
    tail = None
    try:
        branch_name = args[1]
        head = args[2]
        tail = args[3]
    except IndexError:
        print '',
    updateCommits(full_name, branch_name, head, tail)
elif script == 'repo-add':
    repositoryAdd(args[0])
else:
    sys.exit("501 Not implemented")
