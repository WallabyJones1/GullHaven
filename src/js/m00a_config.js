/* ================= Gullhaven: free play and Shells progression =================
   The game and server share these rules. Shells are earned in the game and have no cash value.
   Legacy token and machine settings stay only for save compatibility; their routes are disabled. */
const CFG={
  NAME:'Gullhaven',TICKER:'Shells',SOFT:'Shells',FREE_PLAY:true,
  TOKEN:{
    chain:'solana',cluster:'mainnet-beta',
    mint:'',
    decimals:6,            // SPL decimals of the mint
    treasury:'',           // wallet that receives deposits, licence and co-op fees (its $REEL token account is derived)
    payout:'',             // hot wallet the operator pays withdrawals and prizes from (keys never live in the game)
    nftCollection:'',      // Metaplex collection address for the Founding Fishers
    rpc:'https://api.mainnet-beta.solana.com',
    usdPerReel:0,
    explorer:'https://solscan.io/tx/'
  },
  // Fishing and co-op membership are free, with no wallet or social account required.
  LICENCE:{fee:0,split:{cup:.6,bounty:.25,machine:.15}},
  COOP:{feeDefault:{brine:0,gullwing:0,reef:0,deep:0,mob:0},feeMin:0,feeCap:0,
    split:{treasury:.7,cup:.3},switchPerSeason:1,buckets:['fleet','bait','workshop','dividends','reserve']},
  // The town supports daily Shells prizes alongside the small gameplay fees.
  // the AI crews decide the placings; the members' share of a prize goes to the real members who fished that day (by
  // points, at least minPts each). A co-op with no qualifying members rolls its members' share into tomorrow's Cup.
  CUP:{townGrant:2400,bountyGrant:600,payoutFrac:.7,places:[.36,.24,.18,.13,.09],memberShare:.6,minPts:5,
    rarW:[1,3,9,30,120],firstBonus:6,legendBonus:200,softCap:[600,1500],taper:[1,.5,.2]},
  BOUNTY:{share:.5},       // a legendary catch takes half of the bounty pool
  // Archived machine rules are not available in free play. Collection art is used by the character builder.
  MACHINE:{enabled:false,seed:0,target:12000000,poolTake:.6,crewTake:0,safety:3,
    drop:{n:1,size:100},  // the 500 are released 100 at a time; the operator opens the next drop
    tiers:[{k:'tide',n:'Tidepool',price:10000,nft:.05,col:'#7fdcc0'},{k:'reef',n:'Reef',price:20000,nft:.10,col:'#ff8a7a'},
           {k:'kelp',n:'Kelp',price:30000,nft:.15,col:'#9ccf6a'},{k:'wreck',n:'Wreck',price:40000,nft:.20,col:'#c9a0ff'},
           {k:'abyss',n:'Abyss',price:50000,nft:.25,col:'#ffd24d'}],
    // when no NFT: [multiple, weight]; a hot pool (above target) doubles the weight of the wins
    mults:[[.3,58],[.5,32],[2,8],[5,2]]},
  // Crew sell their fish for Shells. Character rarity gives no gameplay advantage or random currency cheque.
  CREW:{hireShells:[400,900,1800],maxHired:3,ptsShare:.5,nftBonus:1,
    split:{pool:.6,cup:.3,treasury:.1},
    rtp:{hand:.5,nft:[.75,.9,1.08,1.35]},lvlK:.01,lvlCap:.15,
    luck:[[.3,40],[.8,30],[1.5,18],[3,9],[8,3]],
    fund:{seed:0,target:6000,safety:4},
    trips:[{k:'short',n:'Short trip',min:12,fee:25,rolls:6,rtp:0},{k:'half',n:'Afternoon trip',min:60,fee:75,rolls:22,rtp:0},{k:'long',n:'Overnight',min:240,fee:180,rolls:70,rtp:0}]},
  // everything else that feeds the daily Cup
  CUPFEED:{exchange:0,machine:0,derby:0,cosmetic:1},
  DERBY:{entry:0,reward:500},
  COSMETIC:{boatName:80,paint:160},
  // Archived exchange settings; swaps are disabled.
  EXCHANGE:{pool0:{s:600000,r:3000000},fee:.01,dailyReelOut:60000},
  PLAY:{startReel:0,startShells:1200,faucet:0}
};
const reelUsd=n=>n*CFG.TOKEN.usdPerReel;
const fmtUsd=n=>{const v=reelUsd(n);return v>=100?'$'+Math.round(v).toLocaleString('en-US'):v>=1?'$'+v.toFixed(2):'$'+v.toFixed(2)};
