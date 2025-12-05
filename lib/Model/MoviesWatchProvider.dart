class Movieprovider {
    Movieprovider({
        required this.id,
        required this.results,
    });

    final int? id;
    final Results? results;

    Movieprovider copyWith({
        int? id,
        Results? results,
    }) {
        return Movieprovider(
            id: id ?? this.id,
            results: results ?? this.results,
        );
    }

    factory Movieprovider.fromJson(Map<String, dynamic> json){ 
        return Movieprovider(
            id: json["id"],
            results: json["results"] == null ? null : Results.fromJson(json["results"]),
        );
    }

    Map<String, dynamic> toJson() => {
        "id": id,
        "results": results?.toJson(),
    };

    @override
    String toString(){
        return "$id, $results, ";
    }
}

class Results {
    Results({
        required this.ad,
        required this.ag,
        required this.ao,
        required this.ar,
        required this.at,
        required this.au,
        required this.az,
        required this.bb,
        required this.be,
        required this.bf,
        required this.bg,
        required this.bo,
        required this.br,
        required this.bs,
        required this.by,
        required this.bz,
        required this.ca,
        required this.ch,
        required this.cl,
        required this.co,
        required this.cr,
        required this.cv,
        required this.cy,
        required this.cz,
        required this.de,
        required this.dk,
        required this.resultsDo,
        required this.ec,
        required this.ee,
        required this.es,
        required this.fi,
        required this.fr,
        required this.gb,
        required this.gf,
        required this.gr,
        required this.gt,
        required this.gy,
        required this.hk,
        required this.hn,
        required this.hr,
        required this.hu,
        required this.id,
        required this.ie,
        required this.il,
        required this.resultsIn,
        required this.resultsIs,
        required this.it,
        required this.jm,
        required this.jp,
        required this.kr,
        required this.lc,
        required this.lt,
        required this.lu,
        required this.lv,
        required this.mc,
        required this.ml,
        required this.mu,
        required this.mx,
        required this.my,
        required this.mz,
        required this.ni,
        required this.nl,
        required this.no,
        required this.nz,
        required this.pa,
        required this.pe,
        required this.pf,
        required this.pg,
        required this.ph,
        required this.pl,
        required this.pt,
        required this.py,
        required this.se,
        required this.sg,
        required this.si,
        required this.sk,
        required this.sv,
        required this.tc,
        required this.th,
        required this.tr,
        required this.tt,
        required this.tw,
        required this.tz,
        required this.ua,
        required this.ug,
        required this.us,
        required this.uy,
        required this.ve,
        required this.za,
        required this.zw,
    });

    final Ad? ad;
    final Ad? ag;
    final Ao? ao;
    final Ao? ar;
    final Ao? at;
    final Ao? au;
    final Ao? az;
    final Ad? bb;
    final Ao? be;
    final Ao? bf;
    final Ao? bg;
    final Ao? bo;
    final Ao? br;
    final Ad? bs;
    final Ao? by;
    final Ao? bz;
    final Ao? ca;
    final Ao? ch;
    final Ao? cl;
    final Ao? co;
    final Ao? cr;
    final Ao? cv;
    final Ao? cy;
    final Ao? cz;
    final Ao? de;
    final Ao? dk;
    final Ad? resultsDo;
    final Ao? ec;
    final Ao? ee;
    final Ao? es;
    final Ao? fi;
    final Ao? fr;
    final Ao? gb;
    final Ad? gf;
    final Ao? gr;
    final Ao? gt;
    final Ad? gy;
    final Ao? hk;
    final Ao? hn;
    final Ao? hr;
    final Ao? hu;
    final Ao? id;
    final Ao? ie;
    final Ao? il;
    final Ao? resultsIn;
    final Ao? resultsIs;
    final Ao? it;
    final Ad? jm;
    final Ao? jp;
    final Ao? kr;
    final Ad? lc;
    final Ao? lt;
    final Ao? lu;
    final Ao? lv;
    final Ad? mc;
    final Ao? ml;
    final Ao? mu;
    final Ao? mx;
    final Ao? my;
    final Ao? mz;
    final Ao? ni;
    final Ao? nl;
    final Ao? no;
    final Ao? nz;
    final Ad? pa;
    final Ao? pe;
    final Ad? pf;
    final Ao? pg;
    final Ao? ph;
    final Ao? pl;
    final Ao? pt;
    final Ao? py;
    final Ao? se;
    final Ao? sg;
    final Ao? si;
    final Ao? sk;
    final Ad? sv;
    final Ad? tc;
    final Ao? th;
    final Ao? tr;
    final Ad? tt;
    final Ao? tw;
    final Ao? tz;
    final Ao? ua;
    final Ao? ug;
    final Ao? us;
    final Ad? uy;
    final Ao? ve;
    final Ao? za;
    final Ao? zw;

    Results copyWith({
        Ad? ad,
        Ad? ag,
        Ao? ao,
        Ao? ar,
        Ao? at,
        Ao? au,
        Ao? az,
        Ad? bb,
        Ao? be,
        Ao? bf,
        Ao? bg,
        Ao? bo,
        Ao? br,
        Ad? bs,
        Ao? by,
        Ao? bz,
        Ao? ca,
        Ao? ch,
        Ao? cl,
        Ao? co,
        Ao? cr,
        Ao? cv,
        Ao? cy,
        Ao? cz,
        Ao? de,
        Ao? dk,
        Ad? resultsDo,
        Ao? ec,
        Ao? ee,
        Ao? es,
        Ao? fi,
        Ao? fr,
        Ao? gb,
        Ad? gf,
        Ao? gr,
        Ao? gt,
        Ad? gy,
        Ao? hk,
        Ao? hn,
        Ao? hr,
        Ao? hu,
        Ao? id,
        Ao? ie,
        Ao? il,
        Ao? resultsIn,
        Ao? resultsIs,
        Ao? it,
        Ad? jm,
        Ao? jp,
        Ao? kr,
        Ad? lc,
        Ao? lt,
        Ao? lu,
        Ao? lv,
        Ad? mc,
        Ao? ml,
        Ao? mu,
        Ao? mx,
        Ao? my,
        Ao? mz,
        Ao? ni,
        Ao? nl,
        Ao? no,
        Ao? nz,
        Ad? pa,
        Ao? pe,
        Ad? pf,
        Ao? pg,
        Ao? ph,
        Ao? pl,
        Ao? pt,
        Ao? py,
        Ao? se,
        Ao? sg,
        Ao? si,
        Ao? sk,
        Ad? sv,
        Ad? tc,
        Ao? th,
        Ao? tr,
        Ad? tt,
        Ao? tw,
        Ao? tz,
        Ao? ua,
        Ao? ug,
        Ao? us,
        Ad? uy,
        Ao? ve,
        Ao? za,
        Ao? zw,
    }) {
        return Results(
            ad: ad ?? this.ad,
            ag: ag ?? this.ag,
            ao: ao ?? this.ao,
            ar: ar ?? this.ar,
            at: at ?? this.at,
            au: au ?? this.au,
            az: az ?? this.az,
            bb: bb ?? this.bb,
            be: be ?? this.be,
            bf: bf ?? this.bf,
            bg: bg ?? this.bg,
            bo: bo ?? this.bo,
            br: br ?? this.br,
            bs: bs ?? this.bs,
            by: by ?? this.by,
            bz: bz ?? this.bz,
            ca: ca ?? this.ca,
            ch: ch ?? this.ch,
            cl: cl ?? this.cl,
            co: co ?? this.co,
            cr: cr ?? this.cr,
            cv: cv ?? this.cv,
            cy: cy ?? this.cy,
            cz: cz ?? this.cz,
            de: de ?? this.de,
            dk: dk ?? this.dk,
            resultsDo: resultsDo ?? this.resultsDo,
            ec: ec ?? this.ec,
            ee: ee ?? this.ee,
            es: es ?? this.es,
            fi: fi ?? this.fi,
            fr: fr ?? this.fr,
            gb: gb ?? this.gb,
            gf: gf ?? this.gf,
            gr: gr ?? this.gr,
            gt: gt ?? this.gt,
            gy: gy ?? this.gy,
            hk: hk ?? this.hk,
            hn: hn ?? this.hn,
            hr: hr ?? this.hr,
            hu: hu ?? this.hu,
            id: id ?? this.id,
            ie: ie ?? this.ie,
            il: il ?? this.il,
            resultsIn: resultsIn ?? this.resultsIn,
            resultsIs: resultsIs ?? this.resultsIs,
            it: it ?? this.it,
            jm: jm ?? this.jm,
            jp: jp ?? this.jp,
            kr: kr ?? this.kr,
            lc: lc ?? this.lc,
            lt: lt ?? this.lt,
            lu: lu ?? this.lu,
            lv: lv ?? this.lv,
            mc: mc ?? this.mc,
            ml: ml ?? this.ml,
            mu: mu ?? this.mu,
            mx: mx ?? this.mx,
            my: my ?? this.my,
            mz: mz ?? this.mz,
            ni: ni ?? this.ni,
            nl: nl ?? this.nl,
            no: no ?? this.no,
            nz: nz ?? this.nz,
            pa: pa ?? this.pa,
            pe: pe ?? this.pe,
            pf: pf ?? this.pf,
            pg: pg ?? this.pg,
            ph: ph ?? this.ph,
            pl: pl ?? this.pl,
            pt: pt ?? this.pt,
            py: py ?? this.py,
            se: se ?? this.se,
            sg: sg ?? this.sg,
            si: si ?? this.si,
            sk: sk ?? this.sk,
            sv: sv ?? this.sv,
            tc: tc ?? this.tc,
            th: th ?? this.th,
            tr: tr ?? this.tr,
            tt: tt ?? this.tt,
            tw: tw ?? this.tw,
            tz: tz ?? this.tz,
            ua: ua ?? this.ua,
            ug: ug ?? this.ug,
            us: us ?? this.us,
            uy: uy ?? this.uy,
            ve: ve ?? this.ve,
            za: za ?? this.za,
            zw: zw ?? this.zw,
        );
    }

    factory Results.fromJson(Map<String, dynamic> json){ 
        return Results(
            ad: json["AD"] == null ? null : Ad.fromJson(json["AD"]),
            ag: json["AG"] == null ? null : Ad.fromJson(json["AG"]),
            ao: json["AO"] == null ? null : Ao.fromJson(json["AO"]),
            ar: json["AR"] == null ? null : Ao.fromJson(json["AR"]),
            at: json["AT"] == null ? null : Ao.fromJson(json["AT"]),
            au: json["AU"] == null ? null : Ao.fromJson(json["AU"]),
            az: json["AZ"] == null ? null : Ao.fromJson(json["AZ"]),
            bb: json["BB"] == null ? null : Ad.fromJson(json["BB"]),
            be: json["BE"] == null ? null : Ao.fromJson(json["BE"]),
            bf: json["BF"] == null ? null : Ao.fromJson(json["BF"]),
            bg: json["BG"] == null ? null : Ao.fromJson(json["BG"]),
            bo: json["BO"] == null ? null : Ao.fromJson(json["BO"]),
            br: json["BR"] == null ? null : Ao.fromJson(json["BR"]),
            bs: json["BS"] == null ? null : Ad.fromJson(json["BS"]),
            by: json["BY"] == null ? null : Ao.fromJson(json["BY"]),
            bz: json["BZ"] == null ? null : Ao.fromJson(json["BZ"]),
            ca: json["CA"] == null ? null : Ao.fromJson(json["CA"]),
            ch: json["CH"] == null ? null : Ao.fromJson(json["CH"]),
            cl: json["CL"] == null ? null : Ao.fromJson(json["CL"]),
            co: json["CO"] == null ? null : Ao.fromJson(json["CO"]),
            cr: json["CR"] == null ? null : Ao.fromJson(json["CR"]),
            cv: json["CV"] == null ? null : Ao.fromJson(json["CV"]),
            cy: json["CY"] == null ? null : Ao.fromJson(json["CY"]),
            cz: json["CZ"] == null ? null : Ao.fromJson(json["CZ"]),
            de: json["DE"] == null ? null : Ao.fromJson(json["DE"]),
            dk: json["DK"] == null ? null : Ao.fromJson(json["DK"]),
            resultsDo: json["DO"] == null ? null : Ad.fromJson(json["DO"]),
            ec: json["EC"] == null ? null : Ao.fromJson(json["EC"]),
            ee: json["EE"] == null ? null : Ao.fromJson(json["EE"]),
            es: json["ES"] == null ? null : Ao.fromJson(json["ES"]),
            fi: json["FI"] == null ? null : Ao.fromJson(json["FI"]),
            fr: json["FR"] == null ? null : Ao.fromJson(json["FR"]),
            gb: json["GB"] == null ? null : Ao.fromJson(json["GB"]),
            gf: json["GF"] == null ? null : Ad.fromJson(json["GF"]),
            gr: json["GR"] == null ? null : Ao.fromJson(json["GR"]),
            gt: json["GT"] == null ? null : Ao.fromJson(json["GT"]),
            gy: json["GY"] == null ? null : Ad.fromJson(json["GY"]),
            hk: json["HK"] == null ? null : Ao.fromJson(json["HK"]),
            hn: json["HN"] == null ? null : Ao.fromJson(json["HN"]),
            hr: json["HR"] == null ? null : Ao.fromJson(json["HR"]),
            hu: json["HU"] == null ? null : Ao.fromJson(json["HU"]),
            id: json["ID"] == null ? null : Ao.fromJson(json["ID"]),
            ie: json["IE"] == null ? null : Ao.fromJson(json["IE"]),
            il: json["IL"] == null ? null : Ao.fromJson(json["IL"]),
            resultsIn: json["IN"] == null ? null : Ao.fromJson(json["IN"]),
            resultsIs: json["IS"] == null ? null : Ao.fromJson(json["IS"]),
            it: json["IT"] == null ? null : Ao.fromJson(json["IT"]),
            jm: json["JM"] == null ? null : Ad.fromJson(json["JM"]),
            jp: json["JP"] == null ? null : Ao.fromJson(json["JP"]),
            kr: json["KR"] == null ? null : Ao.fromJson(json["KR"]),
            lc: json["LC"] == null ? null : Ad.fromJson(json["LC"]),
            lt: json["LT"] == null ? null : Ao.fromJson(json["LT"]),
            lu: json["LU"] == null ? null : Ao.fromJson(json["LU"]),
            lv: json["LV"] == null ? null : Ao.fromJson(json["LV"]),
            mc: json["MC"] == null ? null : Ad.fromJson(json["MC"]),
            ml: json["ML"] == null ? null : Ao.fromJson(json["ML"]),
            mu: json["MU"] == null ? null : Ao.fromJson(json["MU"]),
            mx: json["MX"] == null ? null : Ao.fromJson(json["MX"]),
            my: json["MY"] == null ? null : Ao.fromJson(json["MY"]),
            mz: json["MZ"] == null ? null : Ao.fromJson(json["MZ"]),
            ni: json["NI"] == null ? null : Ao.fromJson(json["NI"]),
            nl: json["NL"] == null ? null : Ao.fromJson(json["NL"]),
            no: json["NO"] == null ? null : Ao.fromJson(json["NO"]),
            nz: json["NZ"] == null ? null : Ao.fromJson(json["NZ"]),
            pa: json["PA"] == null ? null : Ad.fromJson(json["PA"]),
            pe: json["PE"] == null ? null : Ao.fromJson(json["PE"]),
            pf: json["PF"] == null ? null : Ad.fromJson(json["PF"]),
            pg: json["PG"] == null ? null : Ao.fromJson(json["PG"]),
            ph: json["PH"] == null ? null : Ao.fromJson(json["PH"]),
            pl: json["PL"] == null ? null : Ao.fromJson(json["PL"]),
            pt: json["PT"] == null ? null : Ao.fromJson(json["PT"]),
            py: json["PY"] == null ? null : Ao.fromJson(json["PY"]),
            se: json["SE"] == null ? null : Ao.fromJson(json["SE"]),
            sg: json["SG"] == null ? null : Ao.fromJson(json["SG"]),
            si: json["SI"] == null ? null : Ao.fromJson(json["SI"]),
            sk: json["SK"] == null ? null : Ao.fromJson(json["SK"]),
            sv: json["SV"] == null ? null : Ad.fromJson(json["SV"]),
            tc: json["TC"] == null ? null : Ad.fromJson(json["TC"]),
            th: json["TH"] == null ? null : Ao.fromJson(json["TH"]),
            tr: json["TR"] == null ? null : Ao.fromJson(json["TR"]),
            tt: json["TT"] == null ? null : Ad.fromJson(json["TT"]),
            tw: json["TW"] == null ? null : Ao.fromJson(json["TW"]),
            tz: json["TZ"] == null ? null : Ao.fromJson(json["TZ"]),
            ua: json["UA"] == null ? null : Ao.fromJson(json["UA"]),
            ug: json["UG"] == null ? null : Ao.fromJson(json["UG"]),
            us: json["US"] == null ? null : Ao.fromJson(json["US"]),
            uy: json["UY"] == null ? null : Ad.fromJson(json["UY"]),
            ve: json["VE"] == null ? null : Ao.fromJson(json["VE"]),
            za: json["ZA"] == null ? null : Ao.fromJson(json["ZA"]),
            zw: json["ZW"] == null ? null : Ao.fromJson(json["ZW"]),
        );
    }

    Map<String, dynamic> toJson() => {
        "AD": ad?.toJson(),
        "AG": ag?.toJson(),
        "AO": ao?.toJson(),
        "AR": ar?.toJson(),
        "AT": at?.toJson(),
        "AU": au?.toJson(),
        "AZ": az?.toJson(),
        "BB": bb?.toJson(),
        "BE": be?.toJson(),
        "BF": bf?.toJson(),
        "BG": bg?.toJson(),
        "BO": bo?.toJson(),
        "BR": br?.toJson(),
        "BS": bs?.toJson(),
        "BY": by?.toJson(),
        "BZ": bz?.toJson(),
        "CA": ca?.toJson(),
        "CH": ch?.toJson(),
        "CL": cl?.toJson(),
        "CO": co?.toJson(),
        "CR": cr?.toJson(),
        "CV": cv?.toJson(),
        "CY": cy?.toJson(),
        "CZ": cz?.toJson(),
        "DE": de?.toJson(),
        "DK": dk?.toJson(),
        "DO": resultsDo?.toJson(),
        "EC": ec?.toJson(),
        "EE": ee?.toJson(),
        "ES": es?.toJson(),
        "FI": fi?.toJson(),
        "FR": fr?.toJson(),
        "GB": gb?.toJson(),
        "GF": gf?.toJson(),
        "GR": gr?.toJson(),
        "GT": gt?.toJson(),
        "GY": gy?.toJson(),
        "HK": hk?.toJson(),
        "HN": hn?.toJson(),
        "HR": hr?.toJson(),
        "HU": hu?.toJson(),
        "ID": id?.toJson(),
        "IE": ie?.toJson(),
        "IL": il?.toJson(),
        "IN": resultsIn?.toJson(),
        "IS": resultsIs?.toJson(),
        "IT": it?.toJson(),
        "JM": jm?.toJson(),
        "JP": jp?.toJson(),
        "KR": kr?.toJson(),
        "LC": lc?.toJson(),
        "LT": lt?.toJson(),
        "LU": lu?.toJson(),
        "LV": lv?.toJson(),
        "MC": mc?.toJson(),
        "ML": ml?.toJson(),
        "MU": mu?.toJson(),
        "MX": mx?.toJson(),
        "MY": my?.toJson(),
        "MZ": mz?.toJson(),
        "NI": ni?.toJson(),
        "NL": nl?.toJson(),
        "NO": no?.toJson(),
        "NZ": nz?.toJson(),
        "PA": pa?.toJson(),
        "PE": pe?.toJson(),
        "PF": pf?.toJson(),
        "PG": pg?.toJson(),
        "PH": ph?.toJson(),
        "PL": pl?.toJson(),
        "PT": pt?.toJson(),
        "PY": py?.toJson(),
        "SE": se?.toJson(),
        "SG": sg?.toJson(),
        "SI": si?.toJson(),
        "SK": sk?.toJson(),
        "SV": sv?.toJson(),
        "TC": tc?.toJson(),
        "TH": th?.toJson(),
        "TR": tr?.toJson(),
        "TT": tt?.toJson(),
        "TW": tw?.toJson(),
        "TZ": tz?.toJson(),
        "UA": ua?.toJson(),
        "UG": ug?.toJson(),
        "US": us?.toJson(),
        "UY": uy?.toJson(),
        "VE": ve?.toJson(),
        "ZA": za?.toJson(),
        "ZW": zw?.toJson(),
    };

    @override
    String toString(){
        return "$ad, $ag, $ao, $ar, $at, $au, $az, $bb, $be, $bf, $bg, $bo, $br, $bs, $by, $bz, $ca, $ch, $cl, $co, $cr, $cv, $cy, $cz, $de, $dk, $resultsDo, $ec, $ee, $es, $fi, $fr, $gb, $gf, $gr, $gt, $gy, $hk, $hn, $hr, $hu, $id, $ie, $il, $resultsIn, $resultsIs, $it, $jm, $jp, $kr, $lc, $lt, $lu, $lv, $mc, $ml, $mu, $mx, $my, $mz, $ni, $nl, $no, $nz, $pa, $pe, $pf, $pg, $ph, $pl, $pt, $py, $se, $sg, $si, $sk, $sv, $tc, $th, $tr, $tt, $tw, $tz, $ua, $ug, $us, $uy, $ve, $za, $zw, ";
    }
}

class Ad {
    Ad({
        required this.link,
        required this.flatrate,
    });

    final String? link;
    final List<Flatrate> flatrate;

    Ad copyWith({
        String? link,
        List<Flatrate>? flatrate,
    }) {
        return Ad(
            link: link ?? this.link,
            flatrate: flatrate ?? this.flatrate,
        );
    }

    factory Ad.fromJson(Map<String, dynamic> json){ 
        return Ad(
            link: json["link"],
            flatrate: json["flatrate"] == null ? [] : List<Flatrate>.from(json["flatrate"]!.map((x) => Flatrate.fromJson(x))),
        );
    }

    Map<String, dynamic> toJson() => {
        "link": link,
        "flatrate": flatrate.map((x) => x.toJson()).toList(),
    };

    @override
    String toString(){
        return "$link, $flatrate, ";
    }
}

class Flatrate {
    Flatrate({
        required this.logoPath,
        required this.providerId,
        required this.providerName,
        required this.displayPriority,
    });

    final String? logoPath;
    final int? providerId;
    final String? providerName;
    final int? displayPriority;

    Flatrate copyWith({
        String? logoPath,
        int? providerId,
        String? providerName,
        int? displayPriority,
    }) {
        return Flatrate(
            logoPath: logoPath ?? this.logoPath,
            providerId: providerId ?? this.providerId,
            providerName: providerName ?? this.providerName,
            displayPriority: displayPriority ?? this.displayPriority,
        );
    }

    factory Flatrate.fromJson(Map<String, dynamic> json){ 
        return Flatrate(
            logoPath: json["logo_path"],
            providerId: json["provider_id"],
            providerName: json["provider_name"],
            displayPriority: json["display_priority"],
        );
    }

    Map<String, dynamic> toJson() => {
        "logo_path": logoPath,
        "provider_id": providerId,
        "provider_name": providerName,
        "display_priority": displayPriority,
    };

    @override
    String toString(){
        return "$logoPath, $providerId, $providerName, $displayPriority, ";
    }
}

class Ao {
    Ao({
        required this.link,
        required this.buy,
        required this.rent,
        required this.flatrate,
    });

    final String? link;
    final List<Flatrate> buy;
    final List<Flatrate> rent;
    final List<Flatrate> flatrate;

    Ao copyWith({
        String? link,
        List<Flatrate>? buy,
        List<Flatrate>? rent,
        List<Flatrate>? flatrate,
    }) {
        return Ao(
            link: link ?? this.link,
            buy: buy ?? this.buy,
            rent: rent ?? this.rent,
            flatrate: flatrate ?? this.flatrate,
        );
    }

    factory Ao.fromJson(Map<String, dynamic> json){ 
        return Ao(
            link: json["link"],
            buy: json["buy"] == null ? [] : List<Flatrate>.from(json["buy"]!.map((x) => Flatrate.fromJson(x))),
            rent: json["rent"] == null ? [] : List<Flatrate>.from(json["rent"]!.map((x) => Flatrate.fromJson(x))),
            flatrate: json["flatrate"] == null ? [] : List<Flatrate>.from(json["flatrate"]!.map((x) => Flatrate.fromJson(x))),
        );
    }

    Map<String, dynamic> toJson() => {
        "link": link,
        "buy": buy.map((x) => x.toJson()).toList(),
        "rent": rent.map((x) => x.toJson()).toList(),
        "flatrate": flatrate.map((x) => x.toJson()).toList(),
    };

    @override
    String toString(){
        return "$link, $buy, $rent, $flatrate, ";
    }
}
