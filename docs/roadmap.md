# Roadmap: 7 din ka plan

Is plan mein har din ke kaam hain. Jo "Aap" likha hai wo aapko karna hai, jo "Main" likha hai wo main karunga.

## Abhi ka haal (11 Nov)

- Site par 3 apps ek switch ke saath: Bounty Board, Escrow, Crowdfund.
- Live Netlify site par Bounty Board aur Escrow hain. Crowdfund abhi sirf preview mein hai.
- Escrow ke 101 unit tests pass hue hain. Bounty Board aur Crowdfund ke unit tests nahi hain.
- Maine koi bhi app wallet ke saath poora chala kar nahi dekha. Pehla kaam wahi hai.
- Arc House account approve ho chuka hai.

## Din 1: Test karo (aap, ~30 min)

1. Do MetaMask account banao (A aur B), dono ko Arc Studio ke "Get test USDC" se test USDC lo.
2. Bounty Board: ek bounty post karo, B se submit karo, A se winner chuno.
3. Escrow: A se deal banao, B se accept aur deliver, A se release, phir withdraw.
4. Crowdfund (sirf preview mein): ek campaign banao, deadline "1 hour" rakho, B se pledge karo. Ek ghante baad refund ya payout dekho.
5. Jo bhi galat dikhe, screenshot ke saath mujhe bhej do.

## Din 2: Theek karo (main, aap review)

1. Main aapke bheje hue issues theek karunga.
2. Main Crowdfund ke unit tests chalaunga.
3. Main Crowdfund ko live Netlify site par deploy karunga (aapke "deploy karo" kehne par).
4. Aap site par 1 asli bounty, 1 deal aur 1 campaign chhod do, taaki sab khali na dikhe.

## Din 3: Arc House (aap)

1. Prediction Market wale post par comment ka reply do, aur post mein update line jodo (Update: this link now opens...).
2. XyloNet PayX wale post par apna comment daalo.
3. Naya post tabhi daalo jab Din 1 ke test pass ho gaye ho.

## Din 4: LinkedIn (aap)

1. Escrow ya Crowdfund par ek post, jaisa pehle likha tha. Link `?app=escrow` ya `?app=crowdfund` wala rakho.
2. Ek screenshot lagao (wallet address crop karke).
3. Company ko tag karna ho to `@` type karke asli page chuno.

## Din 5 se 7: Feedback lo (aap)

1. 3 se 5 logon ko link bhejo (dost, Arc Discord) aur kehna "ek baar try karke batao kahan atke".
2. Unke jawab mujhe bhej do. Jo baar baar aaye wo pehle theek karenge.

## Jo post mein daalna hai

- Kya banaya, kisko kya karne ko milta hai (1 se 3 line).
- "Testnet par hai, test USDC chahiye."
- "Arc Studio se banaya, main developer nahi hoon" (sach hai, to rakho).
- Jo limit pata hai wo bhi likho (jaise Bounty Board mein bina deadline ka reward lock reh sakta hai).
- Escrow ke baare mein "101 unit tests pass" likh sakte ho. Bounty Board aur Crowdfund ke liye ye mat likho.
- "Third-party audit nahi hua" zaroor likho.

## Jo nahi karna

- Koi dawa mat karo jo aapne khud chala kar nahi dekha.
- "Fully secure", "audited", "production ready" jaise shabd mat likho.
- Ek hi din mein sab posts mat daalo. Ek app, ek post, alag din.
- Arc House par link bina permission ke mat daalo (guidelines). Pehle rules dekho.
- Apna project share karte waqt batao ki wo aapka hai.
- Private key, seed phrase, ya API key kisi ko ya chat mein mat bhejo.
- Purane post ke link ko bina bataye doosre app par mat badlo. Isse pehle wala Prediction Market jaisa confusion hota hai.

## Baad mein (dhyan se, ek ek karke)

- Integration tests ka flaky run (main).
- Doosri chain se USDC bridge karke fund karna (main, naya Circle package lagega).
- Passkey wallet (pehle aapko Circle Console mein client key banani hogi).
- Naye ideas: Savings Goal, Subscription, Prediction Market wapas (contract abhi chain par hai).

## Roz ka chhota rule

Aaj kuch bhi atke to mujhe screenshot aur "kis step par" bhej do. Main pehle error dekhta hoon, phir batata hoon kya hua.
