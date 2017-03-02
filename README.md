# GitHubToken 
Contract using Oraclize that mint tokens by github commit stats.
 
## Usage 
  
### User Registration
Create a gist in your github containing in it's body only an ethereum address you own.  
Must be in first line with no spaces and no more lines.  
Call `GitHubOracle.register("<your_github_login>","<your gistid>")`  
Example: `GitHubOracle.register("3esmit","31a58f2ddf2258697cce1b969e7c298b")`  
 
### Repository Registration  
Call `GitHubOracle.addRepository("<owner>/<repository>")`  
Example:  `GitHubOracle.addRepository("ethereans/github-token")`  
 
### Claiming Tokens  
Push your commits to github and take the github commitid for each push.
Call `GitHubToken.claim("<commitid>")`  
Example: `GitHubToken.claim("0d3a00941ed72a89f1bf273f17cfd12a0790b82d")`  
There is no need of specifing the user, this is returned by oraclize call, but the user need to be registered in GitHubOracle in order to claim the tokens. 
Anyone can call this, and the tokens will be sent to the address registered in user registry.

### Withdraw donations
When contract enters in lock period just call `GitHubToken.withdraw()` to get your share of the donations.

### Testing in ethereum-studio
This project was created using ethereum-studio. It contains ethereum.json and scenarios. 
Simply clone it in your workspace and you are ready to go.
