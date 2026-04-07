# H3 Experimental Overclock — SmartPi One

## TL;DR

Le CPU H3 (AllWinner) du SmartPi One est limité à **1296 MHz** par la table OPP
du Device Tree (`sun8i-h3.dtsi`). Ce patch ajoute des fréquences expérimentales
jusqu'à **1512 MHz**.

## Analyse technique du hard cap

### Ou se trouve le cap ?

| Couche | Bloquant ? | Details |
|--------|-----------|---------|
| Registre PLL_CPUX | Non | N(5-bit, max 32) x K(2-bit, max 4) = 3072 MHz theorique |
| Driver clock sunxi-ng (`ccu-sun8i-h3.c`) | Non | Pas de `max_rate`, programme tout N/K/M/P valide |
| **Table OPP DTS** (`sun8i-h3.dtsi`) | **OUI** | Derniere entree = 1296 MHz @ 1.34V |
| Gouverneur cpufreq | Indirect | Ne peut demander que les frequences listees dans les OPP |

### Formule PLL_CPUX

```
freq = 24 MHz x N x K / (M x P)
```

| Frequence | N  | K | M | P | Voltage |
|-----------|----|---|---|---|---------|
| 1296 MHz  | 27 | 2 | 1 | 1 | 1.34V (stock) |
| 1368 MHz  | 19 | 3 | 1 | 1 | 1.40V |
| 1488 MHz  | 31 | 2 | 1 | 1 | 1.44V |
| 1512 MHz  | 21 | 3 | 1 | 1 | 1.46V |

Toutes les combinaisons N/K sont dans les limites du registre (N <= 32, K <= 4).

## Methodes d'application

### Methode 1 : Overlay DTS (runtime, sans recompilation kernel)

L'overlay `sun8i-h3-overclock-experimental.dts` peut etre charge au boot.

**Sur un SmartPi One deja en fonctionnement :**

```bash
sudo bash /usr/share/smartpi/install-overclock-overlay.sh
```

Ou manuellement :

```bash
sudo apt install device-tree-compiler
sudo dtc -@ -I dts -O dtb -o /boot/dtb/overlay/sun8i-h3-overclock-experimental.dtbo \
    sun8i-h3-overclock-experimental.dts
echo "user_overlays=sun8i-h3-overclock-experimental" | sudo tee -a /boot/armbianEnv.txt
sudo reboot
```

**Limitation connue** : sur certains kernels mainline, l'overlay OPP peut ne pas
etre pris en compte si le driver cpufreq-dt a deja parse la table au boot.
Dans ce cas, utiliser la Methode 2.

### Methode 2 : Patch kernel (compilation)

Le patch `0001-arm-dts-sun8i-h3-add-experimental-overclock-opp.patch` modifie
directement `sun8i-h3.dtsi` lors de la compilation du kernel.

**Pour l'activer dans le build SmartPi-armbian :**

1. Supprimer les kernel debs pre-compiles (force la recompilation) :
   ```bash
   rm userpatches/header/linux-image-current-sunxi_*.deb
   rm userpatches/header/linux-headers-current-sunxi_*.deb
   ```

2. Le patch est automatiquement pris en compte par Armbian depuis :
   ```
   userpatches/kernel/archive/sunxi-6.6/
   ```

3. Lancer le build normalement. Le kernel compile inclura les OPP etendues
   directement dans le DTB.

**Note** : si la version kernel Armbian change (ex: passe a 6.12), le repertoire
de patches doit etre adapte (`sunxi-6.12/`).

## Verification apres reboot

```bash
# Frequence max exposee par le kernel
cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
# Attendu : 1512000

# Frequences disponibles
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies

# Frequence actuelle
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq

# Forcer une frequence max (ex: 1488 MHz)
echo 1488000 | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

# Temperature CPU (surveiller !)
cat /sys/class/thermal/thermal_zone0/temp
```

## Risques et prerequis

**OBLIGATOIRE :**
- Dissipateur thermique + ventilateur actif
- PMIC AXP209 capable de fournir 1.46V sur VDD-CPUX

**RISQUES :**
- Instabilite (crash, corruption) — silicon lottery
- Degradation acceleree du SoC (electromigration a haute tension)
- Instabilite memoire / USB / Ethernet sous charge
- Throttling thermique si refroidissement insuffisant (seuil ~80C)

**La tension max recommandee par Allwinner pour le H3 est 1.3V.**
Les OPP au-dessus de 1296 MHz depassent cette specification.

## Approche conservative recommandee

Pour un premier test, limiter a 1368 MHz :

```bash
echo 1368000 | sudo tee /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
```

Puis stress-test :

```bash
apt install stress-ng
stress-ng --cpu 4 --timeout 300s --metrics-brief
# Surveiller la temperature en parallele
watch cat /sys/class/thermal/thermal_zone0/temp
```

Si stable pendant 5 minutes sans depasser 75C, essayer 1488 MHz.
