import MultiCanvas "../multiCanvas/multiCanvas";
import AloneCanvas "../aloneCanvas/aloneCanvas";
import IC0 "../common/IC0";
import Types "../common/types";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Cycles "mo:base/ExperimentalCycles";

shared(msg)  actor class Factory () = this {

    type CanvasView = Types.CanvasView;
    //private let WICP_TOKEN : Text = "aanaa-xaaaa-aaaah-aaeiq-cai";

    //private stable var minCyclesCreateCanister: Nat = Types.MINCYCLES_CREATECANISTER; // 2 trillion cycles for each token canister
    //private stable var tipFee: Nat = Types.TIP_FEE;
    private stable var owner: Principal = msg.caller;
    private stable var dimension: Nat = Types.DIMENSION;

    private stable var controlCanisterList : [Principal] = [];
    private var mapCanvasList = HashMap.HashMap<Principal, [var Principal]>(1, Principal.equal, Principal.hash);

    public shared(msg) func createMultiPixelCanvas() : async CanvasView {

        let newCanvas = await MultiCanvas.MultiCanvas(owner, msg.caller, dimension);
        let canvasCid = Principal.fromActor(newCanvas);
        let canResView = await newCanvas.getCanvasView();
        await modityController(canvasCid);
        addCanvasToUser(msg.caller, canvasCid);
        addCanvasIdToControllerList(canvasCid);
        return canResView;
    };

    public shared(msg) func createAlonePixelCanvas() : async CanvasView {

        let newCanvas = await AloneCanvas.AloneCanvas(owner, msg.caller, dimension);
        let canvasCid = Principal.fromActor(newCanvas);
        let canResView = await newCanvas.getCanvasView();
        await modityController(canvasCid);
        addCanvasToUser(msg.caller, canvasCid);
        addCanvasIdToControllerList(canvasCid);
        return canResView;
    };

    public shared(msg) func getCanvasCanisterStatus(canisterId: Principal): async ?IC0.CanisterStatus {
        func checkSame(prinId: Principal): Bool {
            prinId == canisterId
        };
        switch( Array.find( controlCanisterList, checkSame ) ) {
            case (?id) {
                let param: IC0.CanisterId = {
                    canister_id = id;
                };
                let status = await IC0.IC.canister_status(param);
                return ?status;
            };
            case(_) {
                Debug.print(debug_show("not the controller of canister-", canisterId ));
                return null;
            };
        };
    };

    public shared(msg) func modifyOwner(newOwner: Principal) : async () {
        assert(msg.caller == owner);
        owner := newOwner;
    };

    public shared(msg) func modifyDimension(newDimension: Nat) : async Bool {
        assert(msg.caller == owner);
        dimension := newDimension;
        return true;
    };

    public query func balanceCycles() : async Nat {
        return Cycles.balance();
    };

    public func donateCircles() : async Nat {
        Debug.print("before donateCircles: balance before canister: " # Nat.toText(Cycles.balance()));
        let available = Cycles.available();
        assert(available > 0);
        let accepted = Cycles.accept(available);
        Debug.print("accept circles: " # Nat.toText(accepted));
        Debug.print("after donateCircles: balance before canister: " # Nat.toText(Cycles.balance()));
        return accepted;
    };

    private func addCanvasToUser(who: Principal, canisterId: Principal) {
        switch(mapCanvasList.get(who)) {
            case (?canvasList) {
                func checkSame(prinId: Principal): Bool {
                    prinId == canisterId
                };
                switch( Array.find(Array.freeze(canvasList), checkSame) ) {
                    case (?id) {
                        Debug.print(debug_show("pcanvasId alreay exisit:", canisterId ));
                    };
                    case(_) {
                        var canvasNewList : [var Principal] = Array.thaw(Array.append(Array.freeze(canvasList), Array.make(canisterId)));
                        mapCanvasList.put(who, canvasNewList);
                    }
                }
            };
            case (_) {
                mapCanvasList.put(who, Array.thaw(Array.make(canisterId)));
            }
        }
    };

    private func addCanvasIdToControllerList(canisterId: Principal) {
        func checkSame(prinId: Principal): Bool {
            prinId == canisterId
        };

        if( Option.isNull(Array.find(controlCanisterList, checkSame)) ){
            controlCanisterList := Array.append<Principal>(controlCanisterList, Array.make(canisterId));
        };
        // switch( Array.find(controlCanisterList, checkSame ) ) {
        //     case (?id) {
        //         Debug.print(debug_show("pcanvasId alreay exisit:", canisterId ));
        //     };
        //     case(_) {
        //         controlCanisterList := Array.append<Principal>(controlCanisterList, Array.make(canisterId));
        //         //Array.thaw(controlCanisterList);
        //     }
        // }
    };

    private func modityController(canisterId: Principal): async () {

        let controllers: ?[Principal] = ?[owner, Principal.fromActor(this)];
        let settings: IC0.CanisterSettings = {
            controllers = controllers;
            compute_allocation = null;
            memory_allocation = null;
            freezing_threshold = null;
        };
        let params: IC0.UpdateSettingsParams = {
            canister_id = canisterId;
            settings = settings;
        };
        await IC0.IC.update_settings(params);
    };

}