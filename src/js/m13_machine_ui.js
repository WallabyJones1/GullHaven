/* The old capsule machine is now a free character atelier. No pulls or random rewards. */
let gachaOpen=false;
function syncMachine(){}
function openGacha(){openPanel('character')}
function closeGacha(){gachaOpen=false;$('gacha').hidden=true}
function pull(){toast('Choose your fisher freely at the character atelier.');return false}
function gachaFrame(){}
function fitStage(){}
function updMachineUI(){}
