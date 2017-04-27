import sys, os, argparse
import json, urllib2, datetime
from collections import defaultdict
start = ''

def logmsg(msg):
    sys.stderr.write("[GitHubAPI] "+msg+" \n")


try:
    argn = int(os.environ['ARGN'])
except KeyError:
    sys.exit("400 Error") #bad call
if argn < 2:
    sys.exit("404 Error") #no default function
if argn > 3:
    sys.exit("400 Error") #bad call

logmsg("Started " + os.environ['ARG0'] + "(" +  os.environ['ARG1']+")")
    
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
        logmsg("Using OAuth")
        client = auth[0]
        secret = auth[1]
        code = auth[2]
        token = oAuth(client, secret, code)
        auth = 2
    elif len(auth) == 2: #is secret
        logmsg("Using Secret Mode")
        client = auth[0]
        secret = auth[1]
        auth = 1
    elif len(auth) == 1 and len(auth[0]) > 0:
        logmsg("Using Token")
        token = auth[0]
        auth = 2
    else:
        logmsg("Anonymous API")
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
    logmsg("Update commits " + full_name)
    head_end = head
    claim_head = True
    repo_link = getRepositoryURL(full_name)
    repository = json.load(requestAPI(repo_link))
    if branch_name is None:
        branch_name = repository['default_branch']
        logmsg("No branch provided, using default: " + branch_name)
    if head is None and tail is not None: # error
        logmsg("Invalid call")
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
        logmsg (branch_name + " head is "+head_start+".")
        head_end = head
        head_out = head_start
    elif tail is not None and head is not None: #head and tail (continue) = continue from tail
        head_start = tail
        head_end=""
        claim_head=False
        head_out = head
    
    
    tail_out = loadPoints(head_start,head_end,claim_head)
    
    print "["+json.dumps(repository['id'])+",",
    print json.dumps(repository['full_name']) + "," + json.dumps(branch_name) + ",",
    print json.dumps(head_out) + "," + json.dumps(tail_out) + ",",
    print str(len(points)) + ",",
    print json.dumps(points.items()),
    print "]"
    
def __parseLinkHeader(headers):
    links = {}
    if "Link" in headers:
        linkHeaders = headers["Link"].split(", ")
        for linkHeader in linkHeaders:
            (url, rel) = linkHeader.split("; ")
            url = url[1:-1]
            rel = rel[5:-1]
            links[rel] = url
    return links

def loadPoints(head, old_head="", claim_head=True):
    global repo_link
    global count
    global claimed
    global points
    logmsg("Loading from "+head+("" if claim_head else " parent") + (" up to "+old_head if len(old_head) > 0 else "") + ".")
    page = '1'
    while True:  
        response = requestAPI(repo_link + "/commits", [['per_page', '100'], ['sha', head], ['page', page]])
        links = __parseLinkHeader(response.headers)
        commits = json.load(response)
        logmsg(" page "+page+" contains " + str(len(commits)) +" commits.")
        for commit in commits:
            if(int(response.headers.get("X-RateLimit-Remaining")) < 1):
                logmsg("X-RateLimit reached. Try again in "+response.headers.get("X-RateLimit-Reset")+".")
                return tail
            if commit['sha'] == old_head:
                logmsg(commit['sha']+": <reached last commit>")
                return commit['sha']
            else:
                count += 1
                if len(commit['parents']) < 2 and commit['author'] is not None and (claim_head or commit['sha'] != head):
                    if len(points) > 10 and points[author] == 0:
                        logmsg("reached limit of 10 authors.")
                        break
                    commit = json.load(requestAPI(commit['url']))
                    author = commit['author']['login']
                    points[author] += int(commit['stats']['additions'])
                    if(len(commit['parents']) == 0):
                        parent = "<seed>"
                    else:
                        parent = "<"+commit['parents'][0]['sha']+">"
                    logmsg(commit['sha']+": "+ author + " +" + str(commit['stats']['additions']) + " -"+ str(commit['stats']['deletions']) + " |= " + str(commit['stats']['total']) + " " + parent)
                else:
                    if(len(commit['parents']) >= 2):
                        parents = ""
                        for parent in commit['parents']:
                            parents += parent['sha']+", "
                        logmsg(commit['sha'] +": <merge: " + parents[:-2] + ">")
                    elif(commit['author'] is None):
                        logmsg(commit['sha'] +": <unknown author>")
                    else:
                        logmsg(commit['sha'] +": <already claimed>")
                tail = commit['sha']
        try:
            page = links['next'].split('&page=')[1].split('&')[0]
        except KeyError:
            logmsg("Reached end of pagination.")
            break

    return tail

def userRegister(github_user,gistid):
    logmsg("Reading Gist "+gistid+" from "+github_user+".")
    value = json.load(requestAPI("https://api.github.com/gists/" + gistid))
    login = value['owner']['login']
    logmsg("Gist owner is "+login+".")
    if login == github_user:
        content = urllib2.urlopen("https://gist.githubusercontent.com/" + github_user + "/" + gistid + "/raw/").read(42)
        logmsg("Address is "+content);
        print "["+json.dumps(content)+",",
        print json.dumps(value['owner']['id'])+", "+json.dumps(login)+"]"
    else:
        logmsg("Wrong condition: "+github_user+" != "+login);
        sys.exit("403 Forbidden")

def updateIssue(repository,issueid):
    global repo_link
    link_issue = repo_link + "/issues/" + issueid 
    issue = json.load(requestAPI(link_issue))
    print issue['state'] + ", " + datetime.datetime.strptime( json.dumps(issue['closed_at'])[1:-1], "%Y-%m-%dT%H:%M:%SZ" ).strftime('%s') + ", ", 
    
    link_issue = repo_link + "/issues/" + issueid + "/timeline" 
    requestAPI(link_issue, None, ["Accept","application/vnd.github.mockingbird-preview"])
    
    issue = json.load(urllib2.urlopen(req))
    
    for elem in issue:
        if(elem["event"] == "cross-referenced"):
            if(elem["source"]["type"] == "issue"):
                pr = str(elem["source"]["issue"]["number"])
                #print pr
                link_pull = repo_link + "/pulls/" + pr 
                pull = json.load(requestAPI(link_pull))
                if(pull['merged_at']):
                    link_pulls_commits = repo_link + "/pulls/" + pr + "/commits" 
                    commits = json.load(requestAPI(link_pulls_commits))
                    for commit in commits:
                        if(commit['url']):
                            _commit = json.load(requestAPI(commit['url']))
                            author = _commit['author']['login']
                            points[author] += int(json.dumps(_commit['stats']['total']))
    print points.items() 

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
elif script == "issue-update":
    issueUpdate(args[0],args[1])
else:
    sys.exit("501 Not implemented")
