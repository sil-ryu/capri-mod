// Item text for the deck, served through Codeware (TweakXL refers to these LocKey# keys).
module Capri
import Codeware.Localization.*

public class CapriEnglish extends ModLocalizationPackage {

  protected func DefineTexts() -> Void {
    this.Text("Capri-Deck-Name", "Capri");
    this.Text("Capri-Deck-Desc", "An intelligence from beyond the Blackwall, living in your deck. Every quickhack, every tier, no RAM, no cooldowns, instant uploads - and each one jumps to every target you choose. Override turns enemies, drones, mechs and turrets to your side until they die. Capri's own hacks: EMP Shockwave, Blackout, Blackwall Aura and Down Aircraft. Choose targets in the Capri window of the CET overlay.");
    this.Text("Capri-EMP-Name", "EMP Shockwave");
    this.Text("Capri-EMP-Desc", "Capri detonates an electromagnetic pulse from the target. It and everyone around it who matches your targeting get their optics wiped and their systems stunned.");
    this.Text("Capri-Blackout-Name", "Blackout");
    this.Text("Capri-Blackout-Desc", "Capri cuts the city's power grid: every street light and sign goes dark. Upload again to bring the lights back.");
    this.Text("Capri-Aura-Name", "Blackwall Aura");
    this.Text("Capri-Aura-Desc", "Switches Capri's Blackwall aura on or off. While it's on, everyone matching your targeting who comes near you is shocked.");
    this.Text("Capri-DownAircraft-Name", "Down Aircraft");
    this.Text("Capri-DownAircraft-Desc", "Capri seizes the aircraft and blows it out of the sky - along with every aircraft you tagged with the scanner.");
  }
}

public class CapriLocalizationProvider extends ModLocalizationProvider {

  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    if Equals(language, n"en-us") {
      return new CapriEnglish();
    }
    return null;
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}
