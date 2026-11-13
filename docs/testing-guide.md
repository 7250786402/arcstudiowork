# Testing guide (step by step, simple language)

Is guide mein jo likha hai wo bilkul waisa karo. Har step ke saath likha hai "kya dikhna chahiye". Agar waisa nahi dikha, to wahi step ka screenshot lo.
Button ke naam kabhi-kabhi thode alag ho sakte hain. Matlab wahi rakho.

Sabse pehle ye dhyan rakho:
- Ye sab **testnet** hai. Isme asli paise nahi lagte.
- Har transaction ke liye MetaMask mein **ek popup** aata hai. Usme **Confirm** dabana padta hai.
- Gas bhi USDC mein lagta hai. Isliye har account mein thoda extra USDC rakho.
- Ek hi cheez ek baar mein karo. Jaldi mat karo, har step ke baad 5 se 10 second ruko.

---

## Part 0: Taiyari (15 minute, ek hi baar)

### 0.1 Teen MetaMask account banao
Hum teen "log" ban kar test karenge: **A**, **B**, **C**.
1. Browser mein MetaMask kholo (upar puzzle icon, phir MetaMask).
2. Upar jahan account ka naam likha hai (jaise "Account 1") uspar click karo.
3. Neeche **Add account or hardware wallet** dabao. Phir **Ethereum account** chuno.
4. Naam likho: `B` aur **Add account** dabao.
5. Dobara yahi karke teesra account banao, naam `C`.
6. Pehle wale account ka naam badal ke `A` kar do: account ke saamne teen dots, phir **Account details**, naam par pencil.

### 0.2 Teeno ka address copy karke note karo
1. MetaMask mein account chuno.
2. Naam ke neeche jo `0x...` address hai uspar click karo. Copy ho jaata hai.
3. Ek notepad mein likho:
   - A = 0x...
   - B = 0x...
   - C = 0x...
Ye addresses aage kaam aayenge.

### 0.3 Teeno account mein test USDC lo
1. Arc Studio ke sidebar mein **Get test USDC** button dabao.
2. Wahan wallet connect karo (account A chuno). USDC aa jaayega.
3. MetaMask mein account B par jao. Dobara **Get test USDC** dabao, aur B connect karke USDC lo.
4. Yahi C ke liye karo.
5. Agar kuch dino mein limit lag jaaye, to `faucet.circle.com` par jao. Wahan network **Arc Testnet** chuno, token **USDC**, aur apna address paste karke request karo.
6. Har account mein kam se kam **5 USDC** hona chahiye.

### 0.4 App kholo
Normal browser tab mein ye link kholo (jahan MetaMask laga hai):
**https://gleaming-twilight-94b805.netlify.app**
Upar teen tab dikhenge: **Bounty Board**, **Escrow**, **Crowdfund**.

### 0.5 Wallet connect karna
1. Kisi bhi app mein upar **Connect Wallet** dabao.
2. List mein **MetaMask** chuno.
3. MetaMask popup mein account **A** tick karke **Next**, phir **Connect**.
4. Agar red bar aaye "Switch to Arc Testnet", uske **Switch** button par dabao. MetaMask poochega "Add network?" ya "Switch network?". **Approve** dabao.
Ab upar address dikhna chahiye.

### 0.6 Account badalna (B ya C ban-ne ke liye)
Ye bahut baar karna padega, isliye ek baar achhe se samajh lo.
1. MetaMask kholo aur account **B** chuno.
2. App tab par wapas aao. Upar jo address dikh raha hai uspar click karo, phir **Disconnect** dabao.
3. Phir **Connect Wallet**, MetaMask chuno. Popup mein ab sirf **B** ko tick karo, **Connect**.
4. Page refresh karo (F5).
5. Upar address dekho. Pehle 6 aur aakhri 4 akshar B ke address se match hone chahiye.
**Hamesha check karo ki sahi account connect hai**, nahi to buttons nahi dikhenge.

### 0.7 Result likhne ka tareeka
Har test ke saamne **PASS** ya **FAIL** likho. FAIL ho to screenshot lo aur likho kaun sa step tha.

---

## Test 1: Bounty Board (10 minute)
Kya check ho raha hai: koi kaam post kare, doosra submit kare, aur poster winner chune, USDC winner ko mile.

**Taiyari:** account **A** connect hai. Upar **Bounty Board** tab chuno.

### 1.1 A bounty post karta hai
1. Neeche teen tab dikhenge: **Browse**, **Post**, **My bounties**. **Post** dabao.
2. Fields bharo:
   - Title: `Test bounty: write a tagline`
   - Description: `Write one short tagline for a coffee shop called Chai Corner.`
   - What counts as done: `One sentence under 12 words.`
   - Reward: `1` (chip ya box mein)
   - Deadline: **1 week** rehne do.
3. Form ke neeche ek line dikhegi: "You are about to: lock 1 USDC as the reward...". Padh lo. Agar neeche "Still needed: ..." dikhe to wo cheez bharo.
4. **Step 1 of 2: Allow USDC** dabao. MetaMask mein **Confirm**.
5. Button badal ke **Step 2 of 2: Lock 1 USDC as reward** ho jaayega. Dabao. MetaMask mein **Confirm**.
**Kya dikhna chahiye:**
- Upar ek toast: "Transaction sent...", phir "Confirmed on Arc Testnet" (**View** button ke saath).
- Screen ke beech mein ek hara tick animation (1 second).
- Form ke upar ek "Pending" card, jo kuch second baad hat jaata hai.
- **Browse** tab mein tumhari bounty dikhe aur upar ke coin tower mein ek coin ho.

### 1.2 B kaam submit karta hai
1. Account **B** par switch karo (Part 0.6 dekho).
2. **Browse** mein apni bounty par click karo (card khul jaayega).
3. "Your submission" box mein likho: `Chai Corner: the cup that talks back.`
4. **Submit work** dabao. MetaMask mein **Confirm**.
**Kya dikhna chahiye:** card par "1 submission" aur neeche B ka submission, saath mein "you" tag.

### 1.3 A winner chunta hai
1. Wapas **A** par switch karo (Part 0.6).
2. **My bounties** tab kholo. Bounty par click karo.
3. B ke submission ke saath **Pick winner** ka button dabao.
4. Wahin **Confirm** aur **No** aayega. **Confirm** dabao, phir MetaMask mein **Confirm**.
**Kya dikhna chahiye:**
- Tick animation.
- Card par **Awarded** aur "Winner: B".
- Neeche "Onchain activity" mein "Reward paid out" aur **View transaction** link.
- B ke MetaMask mein USDC badh gaya (1 USDC, thoda gas kata hua).

**Result: PASS / FAIL**

---

## Test 2: Escrow, seedha raasta (15 minute)
Kya check ho raha hai: A paisa lock karta hai, B kaam karke "delivered" bolta hai, A release karta hai, B ko paisa milta hai.

**Taiyari:** account **A** connect. Upar **Escrow** tab chuno. Neeche tab dikhenge: **My deals** aur **New deal**.

### 2.1 A deal banata hai
1. **New deal** dabao.
2. Bharo:
   - Seller wallet: **B ka address** paste karo (notepad se).
   - Amount: `1`
   - Title: `Test deal: logo`
   - Terms: `Seller delivers one logo file.`
   - Delivery deadline: **1 week** chip.
   - Auto-release: **3 days** chuno (arbiter khali rehne do). Ye zaroori hai, nahi to "Add an arbiter or an auto-release time" ka warning aayega.
3. Neeche "You are about to: lock 1 USDC in escrow for 0xB..." line padho. Address B ka hai ya nahi, check karo.
4. **Step 1 of 2: Allow USDC**, MetaMask **Confirm**.
5. **Step 2 of 2: Lock 1 USDC in escrow**, MetaMask **Confirm**.
**Kya dikhna chahiye:** toast, tick animation, **My deals** mein deal dikhe, status **Funded**. Upar vault ka darwaza band ho aur "Live" badge ho.

### 2.2 B deal accept aur deliver karta hai
1. **B** par switch karo.
2. **Escrow, My deals** mein deal par click karke kholo.
3. Terms padho. Payout address mein B ka hi address rehne do. **Accept deal** dabao, MetaMask **Confirm**.
4. Status **Accepted** ho jaayega. Ab **I have delivered** dabao, **Confirm**.
**Kya dikhna chahiye:** status **Delivered**.

### 2.3 A release karta hai
1. **A** par switch karo.
2. Deal kholo. **Release 1 USDC to seller** dabao.
3. Ek confirm panel aayega: "Release the payment? 1 USDC will go to 0xB.... This cannot be undone." Padho. **Yes, release it** dabao, MetaMask **Confirm**.
**Kya dikhna chahiye:** status **Released**.

### 2.4 Paisa nikalna (koi bhi kar sakta hai)
1. Deal ke andar **Send 1 USDC to seller payout** dabao. MetaMask **Confirm**.
**Kya dikhna chahiye:**
- B ke wallet mein 1 USDC aa gaya.
- Deal ke andar **Timeline** mein har step ka time aur **View transaction** link. "Seller accepted" step mein link nahi hota, ye theek hai.
- Deal card mein **Copy deal link** dabao, link naye tab mein kholo, wahi deal khule.

**Result: PASS / FAIL**

---

## Test 3: Escrow, vivaad wala raasta (15 minute)
Kya check ho raha hai: deal mein jhagda ho to teesra aadmi (arbiter C) paisa baant deta hai.

### 3.1 A deal banata hai, arbiter C hai
1. **A** connect karo. **Escrow, New deal**.
2. Seller wallet: **B ka address**. Amount: `2`. Title: `Dispute test`. Terms: `Deliver a file.`
3. **Arbiter** wale box mein **C ka address** paste karo.
4. Auto-release **None** rehne do (arbiter hai, isliye chalega).
5. **Allow USDC**, phir **Lock 2 USDC in escrow**. Dono par MetaMask **Confirm**.

### 3.2 B accept aur deliver
1. **B** par switch karo. Deal kholo. **Accept deal**, **Confirm**. Phir **I have delivered**, **Confirm**.

### 3.3 A vivaad uthata hai
1. **A** par switch karo. Deal kholo.
2. **Raise a dispute with the arbiter** dabao, **Confirm**.
**Kya dikhna chahiye:** status **Disputed**.

### 3.4 C faisla karta hai
1. **C** par switch karo (Part 0.6). Deal kholo (C ko "My deals" mein deal dikhegi kyunki wo arbiter hai).
2. "Seller gets (USDC)" box mein `1` likho (matlab 1 USDC seller ko, baaki 1 buyer ko).
3. **Submit decision** dabao, **Confirm**.
**Kya dikhna chahiye:** status **Resolved**.

### 3.5 Dono apna hissa nikalte hain
1. Deal ke andar **Send 1 USDC to buyer** dabao, **Confirm**. A ko 1 USDC wapas.
2. **Send 1 USDC to seller** dabao, **Confirm**. B ko 1 USDC.
(Ye dono button koi bhi account dabaa sakta hai.)

**Result: PASS / FAIL**

---

## Test 4: Crowdfund, refund wala raasta (10 minute, bina wait ke)
Kya check ho raha hai: campaign cancel ho to backer ko paisa wapas mil jaata hai.

### 4.1 A campaign shuru karta hai
1. **A** connect. Upar **Crowdfund** tab. Neeche **Start** dabao.
2. Bharo:
   - Title: `Test campaign`
   - Story: `Testing refunds.`
   - Goal: `5`
   - Duration: **1 hour (for a quick test)** (dropdown se).
   - Send the money to: khali chhod do (A ka wallet use hoga).
3. "You are about to: start a campaign for 5 USDC lasting 1 hour..." line padho.
4. **Start campaign** dabao, **Confirm**.
**Kya dikhna chahiye:** toast, tick animation, **Discover** mein campaign dikhe, ring 0% par.

### 4.2 B pledge karta hai
1. **B** par switch karo. **Discover** mein campaign kholo.
2. "Back this campaign" mein `2` chuno ya likho.
3. **Step 1 of 2** (Allow USDC) dabao, **Confirm**. Phir **Pledge 2 USDC**, **Confirm**.
**Kya dikhna chahiye:** ring bhar kar 40% ho, "You pledged 2 USDC" dikhe, raised 2.00.

### 4.3 A cancel karta hai
1. **A** par switch karo. Campaign kholo. **Cancel campaign** dabao, **Confirm**.
**Kya dikhna chahiye:** status **Cancelled**.

### 4.4 B refund leta hai
1. **B** par switch karo. Campaign kholo.
2. **Take back my 2 USDC** dabao, **Confirm**.
**Kya dikhna chahiye:** B ke wallet mein 2 USDC wapas aa gaya.

**Result: PASS / FAIL**

---

## Test 5: Crowdfund, safal raasta (1 ghante ka wait, baad mein karna)
1. A naya campaign shuru kare: goal `3`, duration **1 hour (for a quick test)**.
2. B `3` USDC pledge kare. Ring 100% ho.
3. **Ek ghanta baad** koi bhi account campaign kholkar **Send 3 USDC to the campaign wallet** dabaye, **Confirm**.
**Kya dikhna chahiye:** status **Paid out** ya similar, aur A ke wallet mein 3 USDC.
Ise sabse pehle shuru kar do, aur ek ghante ke wait mein baaki tests (1, 2, 3, 6) kar lo.

**Result: PASS / FAIL**

---

## Test 6: Chhote checks (10 minute)
- [ ] **Phone ya chhoti window:** browser window chhoti karo (ya phone par kholo). Kuch overlap nahi hona chahiye, buttons aaram se dab sakein.
- [ ] **Galat network:** MetaMask mein network Ethereum Mainnet kar do. App mein laal bar aaye aur **Switch** dabane par wapas Arc Testnet.
- [ ] **Reject karna:** koi transaction shuru karo, MetaMask mein **Reject** dabao. App mein likha aaye "You cancelled this in your wallet. Nothing was sent."
- [ ] **Kam balance:** C account mein bahut kam USDC chhod ke (0.1) bounty post karne ki koshish karo. Saaf message aaye ki USDC kam hai.
- [ ] **Dark mode mein padhna:** hint wale chhote text (form ke neeche wale) aaram se padhe ja sakein.

**Result: PASS / FAIL**

---

## Aakhir mein
1. Neeche ki table bhar do:

| Test | Result | Notes |
|---|---|---|
| 1 Bounty Board | | |
| 2 Escrow seedha | | |
| 3 Escrow vivaad | | |
| 4 Crowdfund refund | | |
| 5 Crowdfund safal | | |
| 6 Chhote checks | | |

2. Jo FAIL hua uska screenshot mujhe bhej do aur bata do kaun sa step. Main khud transaction logs aur console padh lunga, aapko error copy nahi karna.
3. Sab PASS ho jaaye tabhi post mein likho ki "tested". Agar sirf Test 1, 2, 4 pass hue, to bas utna hi likho.

## Agar kuch atke
- **MetaMask popup nahi aaya:** extension icon par click karo, kabhi popup chhup jaata hai.
- **Button disabled hai:** form ke neeche "Still needed: ..." padho.
- **"Not enough USDC":** us account ke liye Get test USDC dobara lo.
- **Status nahi badla:** 15 second ruko, phir refresh icon ya F5.
- **Galat account:** Part 0.6 phir se karo.
