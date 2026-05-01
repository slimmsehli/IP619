
# testplan for the axi4 light register bank
3 main verification section to be validated on this reg bank IP
* 1. Axi light protocol complicance tests
    handshake timing VALID/READY
    channel independence write address vs write data 
    Byte enable/strobe testing 
    error response handeling
* 2. Register level functional tests
    hardware reset and hardware values
    walking 1s walking 0s data path integrity for all registers 
    permission enforcement RO,WO
    Special register types access Write 1 to clear
* 3. stress and edge corner cases
    Back to back transaction
    Read After write Hazard
    Simultaneous AXI internal access 



Registers 0 to 7 : standard read / write 
Registers 8 to 11 : Read Only, write is silently ignored
Registers 12 to 15 : Privileged Read Write Access prot[0] == 1, otherwise SLVERR 2'b10



