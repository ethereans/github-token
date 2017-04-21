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
    return ""

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
        token = oAuth(client, secret, code)
        auth = 2
    elif len(auth) == 2: #is secret
        client = auth[0]
        secret = auth[1]
        auth = 1
    elif len(auth) == 1 and len(auth[0]) > 0:
        token = auth[0]
        auth = 2
    else:
        auth = 0

args = os.environ['ARG1']


def requestAPI(api_link, arguments_get=None, arguments_post=None):
    if arguments_get is None:
        arguments_get = []
    if auth == 1:
        arguments_get += [["client_id", client], ["client_secret", secret]]
    if(auth == 2):
        arguments_post += [["Access-Token",token]]

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
    head_end = head
    claim_head = True
    repo_link = getRepositoryURL(full_name)
    if branch_name is None:
        repo = json.load(requestAPI(repo_link))
        branch_name = repo['default_branch']
    if head is None and tail is not None: # error
        sys.exit("400 Error")
    elif head is None and tail is None: #(new) = from latest head to reachable tail
        branches_link = repo_link + "/branches/" + branch_name
        branch = json.load(requestAPI(branches_link))
        head_start = branch['commit']['sha']
        head_end=""
        head_out = head_start
    elif head is not None and tail is None: #head only (sync) = from latestHead to head
        branches_link = repo_link + "/branches/" + branch_name
        branch = json.load(requestAPI(branches_link))
        head_start = branch['commit']['sha']
        head_out = head_start
    elif tail is not None and head is not None: #head and tail (continue) = continue from tail
        head_start = tail
        head_end=""
        claim_head=False
        head_out = head

    tail_out = loadPoints(head_start,head_end,claim_head)
    print json.dumps(head_out) + "," + json.dumps(tail_out) + ", ",
    print str(len(points)) + ", ",
    print json.dumps(points.items()),

def loadPoints(head, old_head="", claim_head=True):
    global repo_link
    global count
    global claimed
    global points
    while head != old_head:
        commit_link = repo_link + "/commits"
        commits = json.load(requestAPI(commit_link, [['per_page', '100'], ["sha", head]]))
        for commit in commits:
            if commit['sha'] != old_head:
                print "claim "+str(count)+": "+commit['sha'] + " ",
                count += 1
                if len(commit['parents']) < 2 and commit['author'] is not None and (claim_head or commit['sha'] != head):
                    if len(points) > 5 and points[author] == 0:
                        break
                    commit = json.load(requestAPI(commit['url']))
                    author = json.dumps(commit['author']['login'])[1:-1]
                    points[author] += int(commit['stats']['additions'])
                    print author + " +" + str(commit['stats']['additions']) + " -"+ str(commit['stats']['deletions']) + " |= " + str(commit['stats']['total'])
                else:
                    print "<invalid>"
            else:
                print "ended "+str(count)+": "+commit['sha'] 
                break
            head = commit['sha']
        if len(commits) < 100:
            break
    return head

def userRegister(github_user,gistid):
    value = json.load(requestAPI("https://api.github.com/gists/" + gistid))
    login = value['owner']['login']
    if login == github_user:
        print "["+json.dumps(urllib2.urlopen("https://gist.githubusercontent.com/" + github_user + "/" + gistid + "/raw/").read(42))+",",
        print json.dumps(value['owner']['id'])+", "+json.dumps(login)+"]"
    else:
        sys.exit("403 Forbidden")

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
elif script == "user-add":
    userRegister(args[0],args[1])
else:
    sys.exit("501 Not implemented")
