import HashMap "mo:base/HashMap";
import Random "mo:base/Random";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Float "mo:base/Float";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Debug "mo:base/Debug";
import Bool "mo:base/Bool";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Types "../common/types";


shared(msg) actor class MultiCanvas(_owner : Principal, _createUser : Principal,
 _dimension: Nat) = this {
    
    type Pixel = Types.Pixel;
    type Position = Types.Position;
    type Color = Types.Color;
    type Result<T,E> = Result.Result<T,E>;
    type DrawResponse = Types.DrawResponse;
    type CanvasState = Types.CanvasState;
    type CanvasView = Types.CanvasView;

    private stable var owner: Principal = _owner;          // real owner of this canvas, the creator of canister factory
    private stable var creator: Principal = _createUser;   //the user create this canvas
    private stable var dimension: Nat = _dimension;         //canvas's width and length
    private stable var bonusPixelThreshold: Nat = _dimension * _dimension / 2;  //minimum pixel to active bonus
    private stable var isBonusActive: Bool = false;                     
    private stable var isNFTDrawOver: Bool = false;
    private stable var deadline: Nat = Types.ONE_DAY_NANOSECONDS;           // deadline time
    private stable var basicOperatePrice: Nat = Types.BASCIOPERATING_PRICE;     //fee of basic operate
    private stable var growRatio: Nat = 130;                
    private stable var feedBackPercent: Nat = 90;                           //feed fack the 90% price to prev user
    private stable var bonusPercent: Nat = 10;                              //10% price to bonus pool
    private stable var bonusWinnerPercent: Nat = 20;                        //winner get 20% bonus pool
    private stable var bonusNFTTeamPercent: Nat = 25;                       //team get 25% bonus pool
    private stable var bonusCanvasCreatorPercent: Nat = 5;                  //creator of canvas get 5% bonus pool
    private stable var bonusAllUserPercent: Nat = 50;                       //all user get 50% bonus pool
    private stable var nftOwner: ?Principal = null;
    private stable var bonusWinner: ?Principal = null;

    private stable var totalBonus: Nat = 0;
    private stable var allUser: [Principal] = [];
    private stable var balanceState : [(Principal, Nat)] = [];
    private var balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter(balanceState.vals(), 0, Principal.equal, Principal.hash);

    private stable var positionState : [(Position, Pixel)] = [];
    private var canvasState: CanvasState = {
            dimension = dimension;
            board = HashMap.fromIter(positionState.vals(), 0, Types.equal, Types.hash); //HashMap.HashMap<Position, Pixel>(dimension * dimension, Types.equal, Types.hash);
            var last_updated = Time.now();
            deadline = deadline;
            var changeTotal: Nat = 0;
    };

    system func preupgrade() {
        balanceState := Iter.toArray(balances.entries());
        positionState := Iter.toArray(canvasState.board.entries());
    };

    system func postupgrade() {
        balanceState := [];
        positionState := [];
    };

    public shared(msg) func drawPixel(pos: Position, color: Color): async DrawResponse {
        
        assert(not isNFTDrawOver and pos.x < dimension and pos.y < dimension);
        if(canvasState.last_updated + deadline <= Time.now()){
            isNFTDrawOver := true;
            ignore lotteryNFTOwner();
            return #err(#NFTDrawOver);
        };

        let pixel = getNextPixel(pos, msg.caller, color);
        //to do deduct WICP
        saveUser(msg.caller);
        canvasState.board.put(pos, pixel);
        canvasState.last_updated := pixel.last_updated;
        canvasState.changeTotal += 1;
        bonusWinner := Option.make(msg.caller);
        if(canvasState.changeTotal > bonusPixelThreshold){
            isBonusActive := true;
        };

        if(pixel.curPrice > basicOperatePrice){
            let bonus = Nat.div(Nat.mul(pixel.curPrice, bonusPercent), 100);
            totalBonus += bonus;
            var feedBack : Nat = Nat.div(Nat.mul(pixel.curPrice, feedBackPercent), 100);

            switch(balances.get(pixel.prevOwner)){
                case (?b) {
                    balances.put(pixel.prevOwner, b + feedBack);
                };
                case (_) {
                    balances.put(pixel.prevOwner, feedBack);
                };
            };
        };
        #ok(true)
    };

    //produce the nft owner
    public func lotteryNFTOwner(): async ?Principal {
        assert(not isNFTDrawOver and Option.isNull(nftOwner));
        let now = Time.now();
        let entropy = await Random.blob();
        var f = Random.Finite(entropy);
        var randomNat = Option.unwrap(f.byte());
        let size = allUser.size();
        let lotteryIndex = (Int.abs(now) + Nat8.toNat(randomNat)) % size;
        nftOwner := Option.make(allUser[lotteryIndex]);
        nftOwner
    };

    public shared(msg) func withDrawAll(): async () {
        assert(isBonusActive and checkUser(msg.caller));

        var candy:Nat = 0;
        if(isNFTDrawOver){
            candy := totalBonus / allUser.size();
        };
        let balance = queryBalance(msg.caller) + candy;
    };

    public shared(msg) func getBalance() : async Nat {
        queryBalance(msg.caller)
    };

    public query func balanceCycles() : async Nat {
        Cycles.balance()
    };

    public query func queryBonus() : async Nat {
        totalBonus
    };

    public query func queryCreator() : async Principal {
        return creator;
    };

    public query func queryBonusWinner() : async ?Principal {
        assert(canvasState.last_updated + deadline <= Time.now() and isBonusActive and isNFTDrawOver);
        bonusWinner
    };

    public query func isNFTOver() : async Bool {
        isNFTDrawOver
    };

    public func donateCircles() : async Nat {
        let available = Cycles.available();
        assert(available > 0);
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getPixelByPosition(pos: Position) : async ?Pixel {
        canvasState.board.get(pos)
    };

    public query func getCanvasView(): async CanvasView {
        return canvas_state_to_view(canvasState);
    };
     
    private func checkUser(user: Principal) : Bool {
        func checkSame(prinId: Principal): Bool {
            prinId == user
        };
        Option.isSome( Array.find(allUser, checkSame)) 
    };

    private func saveUser(user: Principal) {
        func checkSame(prinId: Principal): Bool {
            prinId == user
        };
        if ( Option.isNull( Array.find(allUser, checkSame)) ) {
            allUser := Array.append<Principal>(allUser, Array.make(user));
        };
    };

    private func queryBalance(user: Principal) : Nat {
        var balance:Nat = 0;
        if(isBonusActive){
            switch(balances.get(user)){
                case (?b) {
                    balance := b;
                };
                case (_) {};
            };
        };
        balance
    };

    private func canvas_state_to_view(canState: CanvasState): CanvasView {
        let canResView = {
            prinId = Principal.fromActor(this);
            dimension = canState.dimension;
            last_updated = canState.last_updated;
            changeTotal = canState.changeTotal;
            expiring = canState.last_updated + deadline < Time.now();
        };
        return canResView;
    };

    private func getNextPixel(pos: Position, user: Principal, color: Color) : Pixel {
        
        switch(canvasState.board.get(pos)){
            case (?pixel) {
                {
                    ownerPixel = user;
                    prevOwner = pixel.ownerPixel;
                    curPrice = Nat.div(Nat.mul(pixel.curPrice, growRatio), 100);
                    color = color;
                    changeCount = pixel.changeCount + 1;
                    last_updated = Time.now();
                }
            };
            case (_) {
                {
                    ownerPixel = user;
                    prevOwner = user;
                    curPrice = basicOperatePrice;
                    color = color;
                    changeCount = 1;
                    last_updated = Time.now();
                }
            };
        };
    };
}