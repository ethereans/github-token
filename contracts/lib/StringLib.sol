pragma solidity ^0.4.9;


library StringLib {

    function hexVal(uint val) internal constant returns (uint){
		//return val - (val < 58 ? 48 : 55); //uppercase
		//return val - (val < 58 ? 48 : 87); //lowercase
		return val - (val < 58 ? 48 : (val < 97 ? 55 : 87)); //both
    }
    
    function toBytes32(string memory source) constant returns (bytes32 result) {
        assembly {
            result := mload(add(source, 32))
        }
    }
    function parseBytes20(string self) 
    constant returns (bytes20 bs) {
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
     constant returns (bytes32 bs) {
        bytes memory h = bytes(self);
        if (h.length>>1 != 32)
            throw;// new Exception("The binary need 20 digits");
        for (uint i = 0; i < 32; ++i)
        {
            bs |= bytes32((byte)((hexVal(uint(h[i << 1])) << 4) + (hexVal(uint(h[(i << 1) + 1])))))>>(8*i);
        }
        return bs;
    }
    function parseAddr(string self) constant returns (address){
        bytes memory tmp = bytes(self);
        uint iaddr = 0;
        for (uint i=2; i<2+2*20; i+=2){
            iaddr += hexVal(uint(tmp[i]))*16+hexVal(uint(tmp[i+1]));
        }
        return address(iaddr);
    }
    
    function compare(string self, string _b) constant returns (int) {
        bytes memory a = bytes(self);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        uint bLength = b.length;
        if (bLength < minLength) minLength = bLength;
        for (uint i = 0; i < minLength; i++)
            byte ai = a[i];
            byte bi = b[i];
            if (ai < bi)
                return -1;
            else if (ai > bi)
                return 1;
        if (minLength < bLength)
            return -1;
        else if (minLength > bLength)
            return 1;
        else
            return 0;
    }

    function indexOf(string _haystack, string _needle) constant returns (int) {
        bytes memory h = bytes(_haystack);
        bytes memory n = bytes(_needle);
        uint hlength = h.length;
        uint nlength = n.length;
        byte n0 = n[0];
        if(hlength < 1 || nlength < 1 || (nlength > hlength))
            return -1;
        else if(hlength > (2**128 -1))
            return -1;
        else
        {
            uint subindex = 0;
            for (uint i = 0; i < hlength; i ++)
            {
                if (h[i] == n0)
                {
                    subindex = 1;
                    byte nsubindex = n[subindex];
                    while(subindex < nlength && (i + subindex) < hlength && h[i + subindex] == nsubindex)
                    {
                        subindex++;
                    }
                    if(subindex == nlength)
                        return int(i);
                }
            }
            return -1;
        }
    }

    // parseInt
    function parseInt(string self) constant returns (uint) {
        return parseInt(self, 0);
    }

    // parseInt(parseFloat*10^_b)
    function parseInt(string self, uint _b) constant returns (uint) {
        bytes memory bresult = bytes(self);
        uint mint = 0;
        bool decimals = false;
        uint bresultlength = bresult.length;
        byte bresulti = bresult[i];
        for (uint i=0; i< bresultlength; i++){
            if ((bresulti >= 48)&&(bresulti <= 57)){
                if (decimals){
                   if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint(bresulti) - 48;
            } else if (bresulti == 46) decimals = true;
        }
        if (_b > 0) mint *= 10**_b;
        return mint;
    }


    function concat(string self, string _b, string _c, string _d, string _e) internal constant returns (string) {
        bytes memory _ba = bytes(self);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        uint _balength = _ba.length;
        uint _bblength = _bb.length;
        uint _bclength = _bc.length;
        uint _bdlength = _bd.length;
        uint _belength = _be.length;
        string memory abcde = new string(_balength + _bblength + _bclength + _bdlength + _belength);
        bytes memory babcde = bytes(abcde);
        uint k = 0;
        for (uint i = 0; i < _balength; i++) babcde[k++] = _ba[i];
        for (i = 0; i < _bblength; i++) babcde[k++] = _bb[i];
        for (i = 0; i < _bclength; i++) babcde[k++] = _bc[i];
        for (i = 0; i < _bdlength; i++) babcde[k++] = _bd[i];
        for (i = 0; i < _belength; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function concat(string self, string _b, string _c, string _d) internal constant returns (string) {
        return concat(self, _b, _c, _d, "");
    }

    function concat(string self, string _b, string _c) internal constant returns (string) {
        return concat(self, _b, _c, "", "");
    }

    function concat(string self, string _b) internal constant returns (string) {
        return concat(self, _b, "", "", "");
    }

}