pragma solidity ^0.4.8;

library JSONLib {
    
    struct JSON {
        bytes b;
        uint8 scan;
    }
    
    function json(string json) internal constant returns (JSON){
        return JSON({ b: bytes(json), scan: 0});
    }
    
   
    function getNextString(JSON self) internal constant returns (string,JSON) {
        uint8 start = 0;
        uint8 end = 0;
        for (;self.b.length > self.scan; self.scan++) {
            if (self.b[self.scan] == '"'){ //Found quotation mark
                if(self.b[self.scan-1] != '\\'){ //is not escaped
	                end = start == 0 ? 0: self.scan;
	                start = start == 0 ? (self.scan+1) : start;
	                if(end > 0) break; 
                }
            }
        }
    	bytes memory str = new bytes(end-start);
        for(self.scan=0; self.scan<str.length; self.scan++){
            str[self.scan] = self.b[start+self.scan];
        }
        for(self.scan=end+1; self.scan<self.b.length; self.scan++) if (self.b[self.scan] == ','){ self.scan++; break; } //end

        return (string(str),self);
	}
	

    function getNextUInt(JSON self) internal constant returns (uint,JSON) {
        uint val = 0;
        for (; self.b.length > self.scan; self.scan++) {
            if (self.b[self.scan] == ','){ //Find ends
                self.scan++; break;
            }else if ((self.b[self.scan] >= 48)&&(self.b[self.scan] <= 57)){ //only ASCII numbers
                val *= 10;
                val += uint(self.b[self.scan]) - 48;
            }
        }
        return (val,self);
    }

    function getNextAddr(JSON self) internal constant returns (address, JSON){
        uint160 iaddr = 0;
        for(;self.b.length > self.scan; self.scan++){
             if (self.b[self.scan] == '0'){ 
                if (self.b[self.scan+1] == 'x'){
                    for (self.scan=self.scan+2; self.scan<2+2*20; self.scan+=2){
                        iaddr *= 256;
                        iaddr += (uint160(hexVal(uint160(self.b[self.scan])))*16+uint160(hexVal(uint160(self.b[self.scan+1]))));
                    }
                    self.scan++; 
                    break;
                }
            }else if (self.b[self.scan] == ','){ 
                self.scan++; 
                break; 
            } 
        }
        return (address(iaddr),self);
    }
    
    function hexVal(uint val) internal constant returns (uint){
		//return val - (val < 58 ? 48 : 55); //uppercase
		//return val - (val < 58 ? 48 : 87); //lowercase
		return val - (val < 58 ? 48 : (val < 97 ? 55 : 87)); //both
    }
}