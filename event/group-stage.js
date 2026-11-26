/* Group configuration is independent of the saved fixture and team records. */
var SagiGroupStage=(function(){
  function clamp(value,min,max,fallback){
    return Math.max(min,Math.min(max,Number.isInteger(value)?value:fallback))
  }
  function groupSizes(teams,count){
    return Array.from({length:count},function(_,i){
      return Math.floor(teams/count)+(i<teams%count?1:0)
    })
  }
  function plan(teams,config){
    if(teams<4)return null;
    config=config||{};
    var maxGroups=Math.floor(teams/2);
    var count=clamp(config.count,2,maxGroups,2);
    var sizes=groupSizes(teams,count);
    var minSize=sizes[sizes.length-1];
    var direct=clamp(config.direct,1,minSize,2);
    var maxWildcards=sizes.filter(function(size){return size>direct}).length;
    var wildcards=clamp(config.wildcards,0,maxWildcards,0);
    var qualifiers=count*direct+wildcards,bracketSize=2;
    while(bracketSize<qualifiers)bracketSize*=2;
    return {
      rules:{count:count,direct:direct,wildcards:wildcards},sizes:sizes,maxGroups:maxGroups,minSize:minSize,maxWildcards:maxWildcards,
      qualifiers:qualifiers,bracketSize:bracketSize,
      groupMatches:sizes.reduce(function(sum,size){return sum+size*(size-1)/2},0)
    }
  }
  function classic(rules){
    return !rules||(rules.count===2&&rules.direct===2&&rules.wildcards===0)
  }
  function labels(count){
    return Array.from({length:count},function(_,i){return String.fromCharCode(65+i)})
  }
  function seedOrder(size){
    var order=[1,2];
    while(order.length<size){
      var nextSize=order.length*2,next=[];
      order.forEach(function(seed){next.push(seed,nextSize+1-seed)});
      order=next
    }
    return order
  }
  function compareAcrossGroups(a,b){
    // Compare rates so a team is not rewarded just for playing more group matches.
    return b.pts*a.p-a.pts*b.p||b.gd*a.p-a.gd*b.p||b.gf*a.p-a.gf*b.p||a.i-b.i
  }
  function qualifiers(tables,rules){
    var ranked=[];
    for(var rank=0;rank<rules.direct;rank++){
      ranked=ranked.concat(tables.map(function(rows){return rows[rank]}).sort(compareAcrossGroups))
    }
    if(rules.wildcards){
      var candidates=tables.map(function(rows){return rows[rules.direct]}).filter(Boolean);
      ranked=ranked.concat(candidates.sort(compareAcrossGroups).slice(0,rules.wildcards))
    }
    return ranked.map(function(row){return row.i})
  }
  return {plan:plan,classic:classic,labels:labels,seedOrder:seedOrder,qualifiers:qualifiers}
})();
