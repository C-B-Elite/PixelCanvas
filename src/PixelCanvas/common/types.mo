import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Hash "mo:base/Hash";

module Types = {

  public let ONE_DAY_NANOSECONDS: Nat = 86_400_000_000_000;
  //public let TIP_FEE: Nat = 10_000_000_000;
  //public let MINCYCLES_CREATECANISTER : Nat = 2_000_000_000_000;
  public let DIMENSION: Nat = 10;
  public let BASCIOPERATING_PRICE: Nat = 50_000_000_000;

  public type Result<T,E> = Result.Result<T,E>;

  public type CommonResult = {
    #InsufficientCycles;
    #OK;
  };

  type BoardHashMap = HashMap.HashMap<Position, Pixel>;

  public type Balance = {
    avaliablebalance: Nat;
    frozonbalance: Nat;
  };

  public type CanvasState = {
    dimension: Nat;
    board: BoardHashMap;
    var last_updated: Time.Time;
    deadline: Nat;
    var changeTotal: Nat;
  };

  public type CanvasView = {
    prinId: Principal;
    dimension: Nat;
    last_updated: Time.Time;
    changeTotal: Nat;
    expiring: Bool;
  };

  public type DrawResponse = Result.Result<Bool, {
    #InsufficientTipFeeCycles;
    #InsufficientOprateFeeCycles;
    #Rejected;
    #NFTDrawOver;
  }>;

  public type Pixel = {
    ownerPixel: Principal;
    prevOwner: Principal;
    curPrice: Nat;
    color: Color;
    changeCount: Nat;
    last_updated: Time.Time;
  };

  public type Color = {
    color: Nat;
  };

  public type Position = {
    x: Nat;
    y: Nat;
  };

  public func equal(a: Position, b: Position) : Bool {
    (a.x == b.x) and (a.y == b.y)
  };
  
  public func hash(a: Position) : Hash.Hash {
    let text = Text.concat(Nat.toText(a.x), Nat.toText(a.y));
    Text.hash(text)
  };

}

