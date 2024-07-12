contract NftItem {
    const minTonsForStorage: Int = ton("0.05");
    const gasConsumption: Int = ton("0.05");

    collection_address: Address;
    item_index: Int; 
    owner: Address;
    individual_content: Cell;
    is_initialized: Bool;

    init(
        collection_address: Address, 
        item_index: Int,
        owner: Address, 
        individual_content: Cell
    ){
        self.collection_address = collection_address;
        self.item_index = item_index;
        self.owner = owner;
        self.individual_content = individual_content;
        self.is_initialized = false;
    }
    receive(msg: Transfer){
        let ctx: Context = context();
        let msgValue: Int = ctx.value;
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = self.minTonsForStorage - min(tonBalanceBeforeMsg, self.minTonsForStorage);
        msgValue = msgValue - (storageFee + self.gasConsumption);

        if (self.is_initialized == false) { 
            self.is_initialized = true; 
            self.owner = msg.new_owner;
            send(SendParameters{
                to: msg.response_destination,
                value: 0,
                mode:  SendIgnoreErrors + SendRemainingValue,
                body: Excesses { 
                        query_id: msg.query_id
                    }.toCell()
                });
        } else {
            let fwdFee: Int = ctx.readForwardFee();
            msgValue = msgValue - fwdFee;
            if (msg.forward_amount == 0 || msg.forward_amount == null) { 
                send(SendParameters{ 
                    to: msg.response_destination,
                    mode: SendIgnoreErrors,
                    value: msgValue,
                    body: Excesses {
                        query_id: msg.query_id
                    }.toCell()
                });
                self.owner = msg.new_owner; current owner to the new_owner
            } else if (msg.forward_amount > 0) { 
                send(SendParameters{
                    to: msg.new_owner,
                    value: msg.forward_amount,
                    mode: SendIgnoreErrors, 
                    bounce: false,
                    body: OwnershipAssigned{
                        query_id: msg.query_id,
                        prev_owner:  self.owner,
                        forward_payload: msg.forward_payload
                    }.toCell()
                }); 
                self.owner = msg.new_owner;
                send(SendParameters{
                    to: msg.response_destination,
                    value: 0,
                    mode: SendIgnoreErrors + SendRemainingValue,
                    body: Excesses {
                        query_id: msg.query_id
                    }.toCell()
                });
            }
        }
    }
    
    receive(msg: GetStaticData){ 
        let nft_init: StateInit = initOf NftItem(
            self.collection_address, 
            self.item_index, 
            self.owner,
            self.individual_content
        );

        let itemAddress: Address = contractAddress(nft_init);
        send(SendParameters{
            to: itemAddress,
            value: 0,
            mode: 64, 
            bounce: true,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.item_index,
                collection: self.owner
            }.toCell(),
            code: nft_init.code,
            data: nft_init.data
        });
    }


    get fun get_nft_data(): GetNftData {
        let b: StringBuilder = beginString();
        let collectionData: String = self.individual_content.asSlice().asString();
        b.append(collectionData);
        b.append(self.item_index.toString());
        b.append(".json");

        return GetNftData {
            is_initialized: self.is_initialized, 
            index: self.item_index, 
            collection_address: self.collection_address, 
            owner_address: self.owner,
            individual_content: b.toCell()
        };
    }
}

message(0x5fcc3d14) Transfer { 
    query_id: Int as uint64;            
    new_owner: Address; 
    response_destination: Address; 
    custom_payload: Cell?; 
    forward_amount: Int as coins; 
    forward_payload: Slice as remaining; 
}
message(0x05138d91) OwnershipAssigned{
    query_id: Int as uint64;
    prev_owner: Address;
    forward_payload: Slice as remaining;
}
message(0xd53276db) Excesses {
    query_id: Int as uint64;
}
message(0x2fcb26a2) GetStaticData { 
    query_id: Int as uint64;
}
message(0x8b771735) ReportStaticData{
    query_id: Int as uint64;
    index_id: Int;
    collection: Address;
}


struct GetNftData { 
    is_initialized: Bool;
    index: Int;
    collection_address: Address; 
    owner_address: Address;
    individual_content: Cell;
}
