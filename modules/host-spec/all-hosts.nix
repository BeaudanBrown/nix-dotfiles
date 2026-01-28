{
  # Master key for failsafe access to all secrets
  masterKey = "age1rundnwzcmw8wltfxdlrhelrkh5m8t80mej4jhfq6prr9k99uxg8qgqvjfw";

  hostSpecs = {
    grill = {
      hostName = "grill";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      tailIP = "100.64.0.5";
      wifi = true;
      ageHostKey = "age16sjq2pmrasnvu447v2qry399tqc45ua8jsc5zv8cwm7vq02lkspsurtu6g";
      ageUserKey = "age1k3fhza4mhr8a5dl3n508m88lcnyy4lnqrfwaz3svdzecq33hzqsq77p7dv";
      roots = [
        "minimal"
        "common"
        "network"
        "client"
        "main"
        "work"
        "gaming"
      ];
    };

    nas = {
      hostName = "nas";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      tailIP = "100.64.0.4";
      wifi = true;
      ageHostKey = "age19v6f4dtenths5ykglat3lmfnfw2wy6yx33um7qyjwzmwk7ndr5lsdrc2a0";
      ageUserKey = "age1xx2x7epqxfq8rusvxswtnxx8czx4z94fzlw0jq59ncgnzds9e95suzfh45";
      roots = [
        "minimal"
        "common"
        "network"
        "main"
        "server"
      ];
    };

    laptop = {
      hostName = "laptop";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      tailIP = "100.64.0.2";
      wifi = true;
      ageHostKey = "age1ta8989w025p3yzxdyan8827a0l05hagm6ac4g9dfnl6xwwmupacsxz3kd0";
      ageUserKey = "age1rl4hv7d8j4wnpchqlswpvw9qtweq8ek2afcvaha6cyjr5fpv2f5s5wrk6s";
      roots = [
        "minimal"
        "common"
        "network"
        "main"
        "work"
      ];
    };

    t480 = {
      hostName = "t480";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      tailIP = "100.64.0.1";
      wifi = true;
      ageHostKey = "age1xcfyee2ujfad8sq8u83rc23ht4akjthrhgx6tn4qef0uq9gh4pss2etw8v";
      ageUserKey = "age10wvkj53rafjcgvvvtmlyx858h2h67jcph8wtp4yp38u00q46uplq2smw3f";
      roots = [
        "minimal"
        "common"
        "gaming"
        "network"
        "client"
        "main"
        "work"
      ];
    };

    pi4 = {
      hostName = "pi4";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      wifi = true;
      ageHostKey = "age193l9m3xmzpn3zqe97fqjkv4dfxqth4d72rzf98ksuc5ctgeal3yst786rk";
      ageUserKey = "age170a0x33mdeghu5mzse59yxdlk4tw3m829fptahxn0gau29kcgd6qr72dlv";
      roots = [
        "minimal"
        "common"
        "network"
        "client"
      ];
    };

    brick = {
      hostName = "brick";
      username = "mikaerem";
      email = "mccarm110@gmail.com";
      userFullName = "Mika";
      tailIP = "100.64.0.12";
      wifi = false;
      ageHostKey = "age1ntdsnyrcnwy700yny3syltatu0avep2jqn2c5z6e68vm9sntcppq6l0aan";
      ageUserKey = "age1pz7m62pecza0kkw0y6nd9zmhvx6rgrwql6f3ejm3j963z63cwadqtnt4cf";
      roots = [
        "minimal"
        "common"
        "network"
        "server"
      ];
    };

    bottom = {
      hostName = "bottom";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      tailIP = "100.64.0.13";
      wifi = false;
      ageHostKey = "age1qa9kz72cuwkm0z2svvmp5e3fdp3da6ru4gwwgempw38e05fqe9zqfct3vv";
      ageUserKey = "age1uvmu8j80cvq08znv54z4fk2hrv9rszcthfa625neq92uhyud5djsj2ayeq";
      roots = [
        "minimal"
        "common"
      ];
    };

    iso = {
      hostName = "iso";
      username = "beau";
      email = "beaudan.brown@gmail.com";
      userFullName = "Beaudan Brown";
      ageHostKey = null; # ISO doesn't need persistent keys
      ageUserKey = null; # ISO doesn't need persistent keys
      roots = [ "minimal" ];
    };
  };
}
