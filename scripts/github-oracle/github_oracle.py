"""Process information from GitHubAPI"""
import sys
import os
import json
import urllib2
import datetime
from collections import defaultdict

def logmsg(msg):
    """Logs a message into proof."""
    sys.stderr.write("[GitHubOracle] "+msg+" \n")

class GitHubAPI:
    """Authentication and API Requests."""
    auth = 0

    def oauth(self, code):
        """Exchanges code for token."""
        req = urllib2.Request("https://github.com/login/oauth/access_token")
        req.add_header("Accept", "application/json")
        req.add_header("client_id", self.client)
        req.add_header("client_secret", self.secret)
        req.add_header("code", code)
        response = urllib2.urlopen(req)
        rjs = json.load(response)
        try:
            logmsg("OAuth success:" + rjs['scope'] + "/" + rjs['token_type'])
            return rjs['access_token']
        except KeyError:
            logmsg("OAuth error " + rjs['error'] + ":" + rjs['error_description'])
            logmsg(rjs['error_uri'])
            sys.exit("403 Forbidden")

    def __init__(self):
        self.argn = int(os.environ['ARGN'])
        if self.argn > 2:
            autharg = [x.strip() for x in os.environ['ARG2'].split(',')]
            if len(autharg) == 3: #is token
                logmsg("Using OAuth")
                self.client = autharg[0]
                self.secret = autharg[1]
                self.token = self.oauth(autharg[2])
                self.auth = 2
            elif len(autharg) == 2: #is secret
                logmsg("Using Secret Mode")
                self.client = autharg[0]
                self.secret = autharg[1]
                self.auth = 1
            elif len(autharg) == 1 and len(autharg[0]) > 0:
                logmsg("Using Token")
                self.token = autharg[0]
                self.auth = 2
            else:
                logmsg("Anonymous API")
                self.auth = 0
        api_link = "https://api.github.com/rate_limit"
        if self.auth == 1:
            req = urllib2.Request(api_link+"?client_id="+self.client+"&client_secret="+self.secret)
        elif self.auth == 2:
            req = urllib2.Request(api_link)
            req.add_header("Access-Token", self.token)
        else:
            req = urllib2.Request(api_link)
        res = json.load(urllib2.urlopen(req))
        self.api = defaultdict(int)
        self.api['rate_limit'] = int(res['rate']['limit'])
        self.api['rate_remaining'] = int(res['rate']['remaining'])
        self.api['rate_reset'] = int(res['rate']['reset'])

    def check_limit(self, more_than=0):
        """Returns True if under limit, else log and return False."""
        if self.api['rate_remaining'] > more_than:
            return True
        else:
            logmsg("X-RateLimit reached. Try again in "+self.api['rate_reset']+".")
            return False

    def request(self, api_link, arguments_get=None, arguments_post=None):
        """Request something to API using authentication."""
        if arguments_get is None:
            arguments_get = []
        if self.auth == 1:
            arguments_get += [["client_id", self.client], ["client_secret", self.secret]]
        if self.auth == 2:
            arguments_post += [["Access-Token", self.token]]
        if len(arguments_get) > 0:
            api_link += "?"
            for argument in arguments_get:
                api_link += argument[0]+"="+argument[1]+"&"
            api_link = api_link[0:-1]
        req = urllib2.Request(api_link)
        if arguments_post is not None and len(arguments_post) > 0:
            for argument in arguments_post:
                req.add_header(argument[0], argument[1])
        response = urllib2.urlopen(req)
        self.api['rate_limit'] = int(response.headers.get("X-RateLimit-Limit"))
        self.api['rate_remaining'] = int(response.headers.get("X-RateLimit-Remaining"))
        self.api['rate_reset'] = int(response.headers.get("X-RateLimit-Reset"))
        return response

class GitRepository:
    """Uses API to load Repository Data"""
    branch = None
    head = ""
    tail = ""
    repo_link = ""
    points = defaultdict(int)
    count = 0

    def __init__(self, api, repository, name=True):
        self.api = api
        if name:
            self.repo_link = "https://api.github.com/repos/"
        else:
            self.repo_link = "https://api.github.com/repositories/"
        self.repo_link += repository
        self.data = json.load(api.request(self.repo_link))
        self.branch_name = self.data['default_branch']

    def set_branch(self, branch_name):
        """Sets the working branch."""
        self.branch = None
        self.branch_name = branch_name

    def set_head(self, head):
        """Set the latest head."""
        self.head = head

    def set_tail(self, tail):
        """Set the further tail"""
        self.tail = tail

    def get_branch(self):
        """Get branch data."""
        logmsg("Loaded branch " + self.branch_name)
        if self.branch is None:
            branches_link = self.repo_link + "/branches/" + self.branch_name
            self.branch = json.load(api.request(branches_link))
        return self.branch

    def __parse_link_header(self, headers):
        links = {}
        if "Link" in headers:
            link_headers = headers["Link"].split(", ")
            for link_header in link_headers:
                (url, rel) = link_header.split("; ")
                url = url[1:-1]
                rel = rel[5:-1]
                links[rel] = url
        return links

    def update_commits(self):
        branch_head = self.get_branch()['commit']['sha']
        logmsg("Loading from "+branch_head+ (" up to "+self.head if len(self.head) > 0 else "") + ".")
        page = '1'
        while self.api.check_limit():
            response = self.api.request(self.repo_link + "/commits", [['per_page', '100'], ['sha', branch_head], ['page', page]])
            commits = json.load(response)
            logmsg("page "+page+" contains " + str(len(commits)) +" commits.")
            for commit in commits:
                if commit['sha'] != self.head:
                    author = commit['author']['id']
                    if self.api.check_limit() and not (len(self.points) > 10 and self.points[author] == 0):
                        self.tail = self.__claim_commit(commit)['sha']
                    else:
                        self.head = branch_head
                        return self.tail
                else:
                    logmsg(commit['sha']+": <last claimed commit>")
                    self.tail = commit['sha']
                    self.head = branch_head
                    return self.tail
            try:
                links = self.__parse_link_header(response.headers)
                page = links['next'].split('&page=')[1].split('&')[0]
            except KeyError:
                logmsg("Reached end of pagination.")
                break
        self.head = branch_head
        return self.tail

    def continue_loading(self, old_tail, limit=""):
        logmsg("Continuing from "+self.head+ (" up to "+limit if len(limit) > 0 else "") +".")
        page = '1'
        claim = False
        while self.api.check_limit():
            response = self.api.request(self.repo_link + "/commits", [['per_page', '100'], ['sha', self.head], ['page', page]])
            commits = json.load(response)
            logmsg("page "+page+" contains " + str(len(commits)) +" commits.")
            for commit in commits:
                if commit['sha'] != limit:
                    if commit['sha'] == old_tail:
                        logmsg(commit['sha']+": <found old tail>")
                        claim = True
                    elif claim:
                        author = commit['author']['id']
                        if self.api.check_limit() and not (len(self.points) > 10 and self.points[author] == 0):
                            self.tail = self.__claim_commit(commit)['sha']
                        else:
                            return self.tail
                else:
                    logmsg(commit['sha']+": <last claimed commit>")
                    self.tail = limit
                    return self.tail
            try:
                links = self.__parse_link_header(response.headers)
                page = links['next'].split('&page=')[1].split('&')[0]
            except KeyError:
                logmsg("Reached end of pagination.")
                break
        return self.tail

    def __claim_commit(self, commit):
        self.count += 1
        if len(commit['parents']) < 2 and commit['author'] is not None:
            commit = json.load(self.api.request(commit['url']))
            author = commit['author']['id']
            self.points[author] += int(commit['stats']['additions'])
            if len(commit['parents']) == 0:
                parent = "<seed>"
            else:
                parent = "<"+commit['parents'][0]['sha']+">"
            logmsg(commit['sha']+": "+  commit['author']['login'] + " ("+str(author) + ") +" + str(commit['stats']['additions']) + " -"+ str(commit['stats']['deletions']) + " |= " + str(commit['stats']['total']) + " " + parent)
        else:
            if len(commit['parents']) >= 2:
                parents = ""
                for parent in commit['parents']:
                    parents += parent['sha']+", "
                logmsg(commit['sha'] +": <merge: " + parents[:-2] + ">")
            elif commit['author'] is None:
                logmsg(commit['sha'] +": <unknown author>")
            else:
                logmsg(commit['sha'] +": <already claimed>")
        return commit

    def issue_points(self, issueid):
        link_issue = self.repo_link + "/issues/" + issueid
        issue = json.load(api.request(link_issue))
        link_issue = self.repo_link + "/issues/" + issueid + "/timeline"
        issue_timeline = self.api.request(link_issue, None, ["Accept", "application/vnd.github.mockingbird-preview"])
        for elem in issue_timeline:
            if elem["event"] == "cross-referenced":
                if elem["source"]["type"] == "issue":
                    pr = str(elem["source"]["issue"]["number"])
                    #print pr
                    link_pull = self.repo_link + "/pulls/" + pr
                    pull = json.load(self.api.request(link_pull))
                    if pull['merged_at']:
                        link_pulls_commits = self.repo_link + "/pulls/" + pr + "/commits"
                        commits = json.load(api.request(link_pulls_commits))
                        for commit in commits:
                            if commit['url']:
                                _commit = json.load(self.api.request(commit['url']))
                                author = _commit['author']['login']
                                self.points[author] += int(json.dumps(_commit['stats']['total']))
        return issue

def user_register(github_user,gistid):
    logmsg("Reading Gist "+gistid+" from "+github_user+".")
    value = json.load(api.request("https://api.github.com/gists/" + gistid))
    login = value['owner']['login']
    logmsg("Gist owner is "+login+".")
    if login == github_user:
        content = urllib2.urlopen("https://gist.githubusercontent.com/" + github_user + "/" + gistid + "/raw/").read(42)
        logmsg("Address is " + content)
        print "["+json.dumps(content)+",",
        print json.dumps(value['owner']['id'])+", "+json.dumps(login)+"]"
    else:
        logmsg("Wrong condition: "+github_user+" != "+login)
        sys.exit("403 Forbidden")



#Script start
try:
    argn = int(os.environ['ARGN'])
except KeyError:
    sys.exit("400 Error") #bad call
if argn < 2:
    sys.exit("404 Error") #no default function
if argn > 3:
    sys.exit("400 Error") #bad call

logmsg("Started " + os.environ['ARG0'] + "(" +  os.environ['ARG1']+")")

script = os.environ['ARG0']
args = [x.strip() for x in os.environ['ARG1'].split(',')]
api = GitHubAPI()

if api.check_limit(5):
    if script == 'update-new':
        repository = GitRepository(api, args[0])
        if len(args) > 1:
            repository.set_branch(args[1])
        if len(args) > 2:
            repository.set_head(args[2])
        repository.update_commits()
        print "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.branch['name']) + ",",
        print json.dumps(repository.head) + "," + json.dumps(repository.tail) + ",",
        print str(len(repository.points)) + ",",
        print json.dumps(repository.points.items()),
        print "]"
    elif script == 'update-old':
        repository = GitRepository(api, args[0])
        repository.set_branch(args[1])
        repository.set_head(args[2])
        try:
            repository.continue_loading(args[3], args[4])
        except IndexError:
            repository.continue_loading(args[3])
        print "["+json.dumps(repository.data['id'])+"," + json.dumps(repository.get_branch()['name']) + ",",
        print json.dumps(repository.head) + "," + json.dumps(repository.tail) + ",",
        print str(len(repository.points)) + ",",
        print json.dumps(repository.points.items()),
        print "]"
    elif script == 'repository-add':
        repository = GitRepository(api, args[0])
        print "["+json.dumps(repository.data['id'])+",",
        print json.dumps(repository.data['full_name'])+",",
        print json.dumps(repository.data['watchers_count'])+",",
        print json.dumps(repository.data['stargazers_count'])+"]"
    elif script == "user-add":
        user_register(args[0], args[1])
    elif script == "issue-update":
        repository = GitRepository(api, args[0])
        issue = repository.issue_points(args[1])
        print "["+json.dumps(repository.data['id'])+"," + json.dumps(issue['id']),
        print json.dumps(issue['state']) + ", " + datetime.datetime.strptime(issue['closed_at'], "%Y-%m-%dT%H:%M:%SZ").strftime('%s') + ", ",
        print str(len(repository.points)) + ",",
        print json.dumps(repository.points.items()),
        print "]"
    else:
        sys.exit("501 Not implemented")
else:
    sys.exit("503 Service Unavailable")
