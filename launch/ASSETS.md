# Gullhaven Fishers: 3,333 pixel-art fishers for Solana

64 x 64 chest-up portraits, painted in code with the same colour ramp as the game's
characters, then scaled up to 1024 x 1024 with hard pixel edges.

## What's here

- `assets/`: `0.png` to `3332.png`, a matching `0.json` to `3332.json` in the Metaplex
  token-metadata format, plus `collection.png` and `collection.json`. This is the folder
  layout Sugar (Metaplex Candy Machine) expects.
- `rarity.csv`: every fisher ranked by rarity (information score: rarer traits add more).
- `trait_counts.csv`: how many of each trait value exist.
- `rarest_48.png` and `first_240.png`: contact sheets.

Every fisher has a unique set of visible traits, and every image file is different.

## Traits (15)

| Trait | Values | Rarest |
|---|---|---|
| Background | 8 solid colours + 9 scenes | Gold, To The Moon, Mainnet Grid |
| Skin | 13 | Gradient, Gold, Ghost, Robot |
| Hair / Hair Colour | 16 styles / 14 colours | Gradient, Purple, Mint hair |
| Eyes | 13 | Mint Laser, Laser, Hearts, Stars |
| Mouth | 13 | Fish Snack, Bubblegum, Gold Tooth |
| Facial Hair | 7 | Handlebar |
| Clothing / Clothing Colour | 24 / 13 | Validator Jacket, Robe, Gradient anything |
| Hat / Hat Colour | 31 + none / 14 | Gradient Crown, Astronaut Helmet, Crown |
| Eyewear | 13 + none | VR Visor, Monocle, Dive Mask |
| Necklace | 8 + none | Diamond Chain, Gradient Gem, Cold Wallet |
| Earring | 5 + none | Gradient Drop, Diamond |
| Pet | 7 + none | Octopus, Parrot |

Solana-flavoured items use the purple-to-mint colours and crypto culture (GM, WAGMI and
HODL tees, candle charts, a cold-wallet pendant, laser eyes, the Validator Jacket).
None of them use the Solana logo or wordmark, which are trademarks of the Solana
Foundation.

## Change it and make it again

```
python3 tools/nft/catalog.py           # one sheet per trait, every item side by side
python3 tools/nft/preview.py 36 7      # 36 random fishers from seed 7
python3 tools/nft/generate.py          # the full 3,333 into nft/assets (seed 2026)
python3 tools/nft/generate.py --count 3333 --seed 99 --out nft/assets
```

- Art: `tools/nft/portrait.py`. Each item is a few shapes, auto-shaded and outlined by
  `tools/nft/canvas.py`.
- Weights and rules: `tools/nft/traits.py`. A higher weight means more common. The rules
  stop clashes, such as a hat with the hood up, or lasers crossing a shoulder pet.
- Name, symbol (`GULLF`), description and the 5% royalty in the JSON: the top of
  `tools/nft/generate.py`.

The same seed always gives the same collection.

## Minting (you do this, with your wallet)

1. Install Metaplex Sugar (see developers.metaplex.com).
2. Run `sugar create-config` from this folder. Set your creator wallet address,
   royalties, price, go-live date and storage.
3. Then run `sugar validate`, `sugar upload`, `sugar deploy` and `sugar verify`.

Try the whole run on devnet first.
