# Vercel par deploy karna (bilkul shuru se)

Pehle ek baat: ye zaroori nahi hai. App Netlify par live hai. Ye guide sirf tab follow karo jab aapko Vercel par bhi chahiye.
Tumhe lagbhag 10 minute lagenge.

## Step 1: Vercel account banao (free)
1. Browser mein `vercel.com` kholo.
2. Upar **Sign Up** dabao.
3. Plan poochhe to **Hobby** chuno (free). Ye personal use ke liye hai.
4. Naam likho, phir **Continue with GitHub** dabao.
   (Wahi GitHub account chuno jisme `arcstudiowork` repo hai, yaani `7250786402`.)
5. GitHub poochhega "Authorize Vercel". **Authorize** dabao.
Account ban gaya.

## Step 2: Repo import karo
1. Vercel ke dashboard mein **Add New...** dabao, phir **Project**.
2. Agar repo list mein na dikhe, to **Adjust GitHub App Permissions** dabao aur `arcstudiowork` repo ko allow karo.
3. List mein `arcstudiowork` ke saamne **Import** dabao.

## Step 3: Settings bharo (sabse zaroori)
Import ke baad ek "Configure Project" page khulega. Ye teen cheezein badlo:

**a) Framework Preset:** `Vite` chuno (aksar khud chun jaata hai).

**b) Build and Output Settings:** is hisse ko kholo (arrow dabao).
- **Build Command:** **Override** ka switch on karo aur likho:
  `vite build`
- **Output Directory:** **Override** on karo aur likho:
  `dist`
(Isliye ki is project mein "build" naam ka shortcut nahi hai, to default command fail ho jaata.)

**c) Environment Variables:** is hisse ko kholo. Do variables add karo:

| Name | Value |
|---|---|
| `VITE_ESCROW_ADDRESS` | `0x3addc8c4e5ca5f7e98a61ebc3c7232ef09cb3b6c` |
| `VITE_CROWDFUND_ADDRESS` | `0x008a328ad702578c39d00517efa8b8abe6d05b39` |

Har ek ke liye Name aur Value bharo, phir **Add** dabao. (Ye public contract addresses hain, koi secret nahi.)

## Step 4: Deploy
1. Neeche **Deploy** dabao.
2. 1 se 2 minute ruko. Screen par logs chalte dikhenge.
3. Safal hone par "Congratulations" aur ek link dikhega, jaise `arcstudiowork-xxxx.vercel.app`.

## Step 5: Check karo
Link kholo aur ye dekho:
- Upar teen tab: Bounty Board, Escrow, Crowdfund.
- Teeno tab mein koi laal error nahi.
- Escrow aur Crowdfund tab khali ya toote nahi dikhne chahiye (agar toote hain to Step 3c ke variables galat ya chhoote hain).
- Link ke end mein `?app=escrow` lagao, seedha Escrow khulna chahiye.

## Agar fail ho
- **"Command not found: build" ya "missing script: build":** Step 3b nahi hua. Project, Settings, Build and Output Settings mein jakar Build Command `vite build` karo, phir **Deployments, Redeploy**.
- **Escrow ya Crowdfund khali:** Settings, Environment Variables mein dono variables dobara check karo, phir Redeploy. (Variables badalne ke baad Redeploy zaroori hai.)
- **Kuch aur:** build logs ka screenshot mujhe bhej do.

## Baad mein
- Code GitHub par update hoga to Vercel apne aap naya deploy kar deta hai.
- Post mein ek hi link do (Netlify ya Vercel), dono mat do.
