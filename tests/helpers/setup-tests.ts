import { sleep } from "../../library-sui/src";
import { deploy, genesis } from "../../scripts/";

async function main() {
    await deploy();
    await sleep(2000);
    await genesis();
}

if (require.main === module) {
    main();
}
