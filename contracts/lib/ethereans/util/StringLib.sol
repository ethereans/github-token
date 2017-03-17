pragma solidity ^0.4.9;


library StringLib {
    
    function str(string self) internal returns (string){
        return self;
    }
    
    function hexVal(uint val) internal returns (uint){
		//return val - (val < 58 ? 48 : 55); //uppercase
		//return val - (val < 58 ? 48 : 87); //lowercase
		return val - (val < 58 ? 48 : (val < 97 ? 55 : 87)); //both
    }
    
    function toBytes32(string memory source) internal returns (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }
    function parseBytes20(string self) 
    internal returns (bytes20 bs) {
        bytes memory h = bytes(self);
        if (h.length>>1 != 20)
            throw;// new Exception("The binary need 20 digits");
        for (uint i = 0; i < 20; ++i)
        {
            bs |= bytes20((byte)((hexVal(uint(h[i << 1])) << 4) + (hexVal(uint(h[(i << 1) + 1])))))>>(8*i);
        }
        return bs;
    }
    function parseBytes32(string self) 
     internal returns (bytes32 bs) {
        bytes memory h = bytes(self);
        if (h.length>>1 != 32)
            throw;// new Exception("The binary need 20 digits");
        for (uint i = 0; i < 32; ++i)
        {
            bs |= bytes32((byte)((hexVal(uint(h[i << 1])) << 4) + (hexVal(uint(h[(i << 1) + 1])))))>>(8*i);
        }
        return bs;
    }
    function parseAddr(string self) internal returns (address){
        bytes memory tmp = bytes(self);
        uint iaddr = 0;
        for (uint i=2; i<2+2*20; i+=2){
            iaddr += hexVal(uint(tmp[i]))*16+hexVal(uint(tmp[i+1]));
        }
        return address(iaddr);
    }
    
    function compare(string self, string _b) internal returns (int) {
        bytes memory a = bytes(self);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }

    function indexOf(string _haystack, string _needle) internal returns (int) {
        bytes memory h = bytes(_haystack);
        bytes memory n = bytes(_needle);
        if(h.length < 1 || n.length < 1 || (n.length > h.length))
            return -1;
        else if(h.length > (2**128 -1))
            return -1;
        else
        {
            uint subindex = 0;
            for (uint i = 0; i < h.length; i ++)
            {
                if (h[i] == n[0])
                {
                    subindex = 1;
                    while(subindex < n.length && (i + subindex) < h.length && h[i + subindex] == n[subindex])
                    {
                        subindex++;
                    }
                    if(subindex == n.length)
                        return int(i);
                }
            }
            return -1;
        }
    }

    function concat(string self, string _b, string _c, string _d, string _e) internal returns (string) {
        bytes memory _ba = bytes(self);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(_ba.length + _bb.length + _bc.length + _bd.length + _be.length);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function concat(string self, string _b, string _c, string _d) internal returns (string) {
        return concat(self, _b, _c, _d, "");
    }

    function concat(string self, string _b, string _c) internal returns (string) {
        return concat(self, _b, _c, "", "");
    }

    function concat(string self, string _b) internal returns (string) {
        return concat(self, _b, "", "", "");
    }

    // parseInt
    function parseInt(string self) internal returns (uint) {
        return parseInt(self, 0);
    }

    // parseInt(parseFloat*10^_b)
    function parseInt(string self, uint _b) internal returns (uint) {
        bytes memory bresult = bytes(self);
        uint mint = 0;
        bool decimals = false;
        for (uint i=0; i<bresult.length; i++){
            if ((bresult[i] >= 48)&&(bresult[i] <= 57)){
                if (decimals){
                   if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint(bresult[i]) - 48;
            } else if (bresult[i] == 46) decimals = true;
        }
        if (_b > 0) mint *= 10**_b;
        return mint;
    }


    

    

}