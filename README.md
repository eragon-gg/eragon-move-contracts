# Eragon Move Contracts



### Compiles
```
aptos move compile --named-addresses eragon=default
or 
aptos move publish --named-addresses eragon=default --skip-fetch-latest-git-deps
```

### Test
```
aptos move test --named-addresses eragon=default --ignore-compile-warnings
````

### Deploy
```
aptos move publish --named-addresses eragon=default
```


## Init random rules

The random rules are defined in the Excel file at `scripts/data/Profile_wheel_data.xlsx` and `scripts/data/Equipment_data.xlsx`.

Copy the `.env.example` to `.env` file and replace it with your addresses & private keys.

Run the command to init config, which calls the function on the Game contract deployed above.

```sh
cd developer/scripts
node initConfigs.js
```

Now, you can run & check the random results by

```sh
cd developer/scripts
node randomness.js
```
