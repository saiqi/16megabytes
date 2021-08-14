module vulpes.core.operations;
import std.range;
import std.typecons : Tuple, Nullable, nullable;
import std.functional : binaryFun;
import std.traits : arity;

auto sortRange(alias sortFunc, R)(R range)
if(isInputRange!R)
{
    import std.algorithm : sort;
    static if(isRandomAccessRange!R && hasSwappableElements!R && hasSlicing!R && hasLength!R)
    {
        return range.sort!sortFunc;
    }
    else
    {
        import std.array : array;
        return range.array.sort!sortFunc;
    }
}

mixin template JoinMixin(alias leftKeyFunc, alias rightKeyFunc, R1, R2)
{
    private:
    alias leftSortFunc = (a ,b) => leftKeyFunc(a) < leftKeyFunc(b);
    alias rightSortFunc = (a, b) => rightKeyFunc(a) < rightKeyFunc(b);
    SortedRange!(ElementType!R1[], leftSortFunc) left_;
    SortedRange!(ElementType!R2[], rightSortFunc) right_;
    alias comp = binaryFun!"a < b";
}

auto intersect(alias leftKeyFunc, alias rightKeyFunc, R1, R2)(R1 left, R2 right)
if(isInputRange!R1 && isInputRange!R2)
{
    static struct InnerJoinResult(alias leftKeyFunc, alias rightKeyFunc, R1, R2)
    {
        private:
        mixin JoinMixin!(leftKeyFunc, rightKeyFunc, R1, R2);
        alias InnerJoinItem = Tuple!(ElementType!R1, "left", ElementType!R2, "right");

        void adjustPosition()
        {
            if(empty) return;

            if(comp(rightKeyFunc(right_.front), leftKeyFunc(left_.front)))
            {
                do
                {
                    right_.popFront();
                    if(right_.empty) return;
                } while(comp(rightKeyFunc(right_.front), leftKeyFunc(left_.front)));
            }

            if(comp(leftKeyFunc(left_.front), rightKeyFunc(right_.front)))
            {
                do
                {
                    left_.popFront();
                    if(left_.empty) return;
                } while(comp(leftKeyFunc(left_.front), rightKeyFunc(right_.front)));
            }
        }

        public:
        this(R1 left, R2 right)
        {
            this.left_ = left.sortRange!leftSortFunc;
            this.right_ = right.sortRange!rightSortFunc;
            adjustPosition();
        }

        @property bool empty()
        {
            return left_.empty || right_.empty;
        }

        @property auto front()
        {
            assert(!empty);
            return InnerJoinItem(left_.front, right_.front);
        }

        void popFront()
        {
            assert(!empty);
            left_.popFront();
            right_.popFront();
            adjustPosition();
        }

        auto save()
        {
            auto retval = this;
            retval.left_ = left_.save;
            retval.right_ = right_.save;
            return retval;
        }
    }
    return InnerJoinResult!(leftKeyFunc, rightKeyFunc, R1, R2)(left, right);
}

unittest
{
    import std.range : iota;
    import std.algorithm : map, filter;

    auto r1 = iota(3).map!(i => Foo(i))
        .intersect!(f => f.id, b => b.key)(
            iota(3).filter!(i => i%2 == 0).map!(i => Bar(i)));
    assert(!r1.empty);
    assert(r1.front[0] == Foo(0) && r1.front[1] == Bar(0));
    r1.popFront();
    assert(r1.front[0] == Foo(2) && r1.front[1] == Bar(2));
    r1.popFront();
    assert(r1.empty);

    auto r2 = iota(3).map!(i => Foo(i))
        .intersect!(f => f.id, b => b.key)(
            iota(4).filter!(i => i >= 3).map!(i => Bar(i)));
    assert(r2.empty);

    auto r3 = iota(3).filter!(i => i%2 == 0).map!(i => Foo(i))
        .intersect!(f => f.id, b => b.key)(
            iota(3).map!(i => Bar(i)));
    assert(!r3.empty);
    assert(r3.front[0] == Foo(0) && r3.front[1] == Bar(0));
    r3.popFront();
    assert(r3.front[0] == Foo(2) && r3.front[1] == Bar(2));
    r3.popFront();
    assert(r3.empty);

}

unittest
{
    auto left = [1, 2, 3];
    auto right = [2, 3, 4];

    auto r = left.intersect!(x => x, x => x)(right);
    auto rs = r.save;

    r.popFront();
    assert(r.front.left == 3);
    assert(rs.front.left == 2);
}

auto leftouterjoin(alias leftKeyFunc, alias rightKeyFunc, R1, R2)(R1 left, R2 right)
if(isInputRange!R1 && isInputRange!R2)
{
    static struct LeftOuterJoinResult(alias leftKeyFunc, alias rightKeyFunc, R1, R2)
    {
        private:
        mixin JoinMixin!(leftKeyFunc, rightKeyFunc, R1, R2);
        alias LeftOuterJoinItem = Tuple!(ElementType!R1, "left", Nullable!(ElementType!R2), "right");

        void adjustPosition()
        {
            if(left_.empty || right_.empty) return;

            if(comp(rightKeyFunc(right_.front), leftKeyFunc(left_.front)))
            {
                do
                {
                    right_.popFront();
                    if(right_.empty) return;
                } while(comp(rightKeyFunc(right_.front), leftKeyFunc(left_.front)));
            }
        }

        public:
        this(R1 left, R2 right)
        {
            this.left_ = left.sortRange!leftSortFunc;
            this.right_ = right.sortRange!rightSortFunc;
            adjustPosition();
        }

        @property bool empty()
        {
            return left_.empty;
        }

        @property auto front()
        {
            assert(!empty);

            if(right_.empty) return LeftOuterJoinItem(this.left_.front, Nullable!(ElementType!R2).init);

            return rightKeyFunc(right_.front) == leftKeyFunc(left_.front)
                ? LeftOuterJoinItem(left_.front, right_.front.nullable)
                : LeftOuterJoinItem(left_.front, Nullable!(ElementType!R2).init);

        }

        void popFront()
        {
            assert(!empty);
            left_.popFront();
            adjustPosition();
        }

        auto save()
        {
            auto retval = this;
            retval.left_ = left_.save;
            retval.right_ = right_.save;
            return retval;
        }
    }
    return LeftOuterJoinResult!(leftKeyFunc, rightKeyFunc, R1, R2)(left, right);
}

version(unittest)
{
    static struct Foo
    {
        int id;
    }

    static struct Bar
    {
        int key;
    }
}

unittest
{
    import std.range : iota, walkLength;
    import std.algorithm : map, filter, all;

    auto r1 = iota(3).map!(i => Foo(i))
        .leftouterjoin!(f => f.id, b => b.key)(
            iota(3).filter!(i => i%2 == 0).map!(i => Bar(i)));
    assert(!r1.empty);
    assert(r1.front[0] == Foo(0) && r1.front[1].get == Bar(0));
    r1.popFront();
    assert(r1.front[0] == Foo(1) && r1.front[1].isNull);
    r1.popFront();
    assert(r1.front[0] == Foo(2) && r1.front[1].get == Bar(2));
    r1.popFront();
    assert(r1.empty);

    auto r2 = iota(3).map!(i => Foo(i))
        .leftouterjoin!(f => f.id, b => b.key)(
            iota(4).filter!(i => i >= 3).map!(i => Bar(i)));
    assert(r2.walkLength == 3);
    assert(r2.all!"a[1].isNull");

    auto r3 = iota(3).filter!(i => i%2 == 0).map!(i => Foo(i))
        .leftouterjoin!(f => f.id, b => b.key)(
            iota(3).map!(i => Bar(i)));
    assert(!r3.empty);
    assert(r3.front[0] == Foo(0) && r3.front[1].get == Bar(0));
    r3.popFront();
    assert(r3.front[0] == Foo(2) && r3.front[1].get == Bar(2));
    r3.popFront();
    assert(r3.empty);
}

unittest
{
    auto left = ["FREQ"];
    auto right = ["FREQ", "INDICATEUR", "ACTIVITE", "SECT-INST", "FINANCEMENT", "OPERATION", "COMPTE", "NATURE-FLUX",
    "FORME-VENTE", "MARCHANDISE", "QUESTION", "INSTRUMENT", "PRODUIT", "NATURE", "METIER", "TYPE-ENT", "CAUSE-DECES",
    "CAT-DE", "TYPE-ETAB", "FONCTION", "FACTEUR-INV", "DEST-INV", "ETAT-CONSTRUCTION", "DEMOGRAPHIE", "TOURISME-INDIC",
    "TYPE-EMP", "TYPE-SAL", "CLIENTELE", "LOCAL", "LOGEMENT", "TYPE-MENAGE", "CARBURANT", "FORMATION", "EFFOPE",
    "SPECIALITE-SANTE", "ACCUEIL-PERS-AGEES", "DIPLOME", "ETAB-SCOL", "GEOGRAPHIE", "ZONE-GEO", "RESIDENCE",
    "LOCALISATION", "TYPE-EVO", "SEXE", "TYPE-FLUX", "CAT-FP", "PERIODE", "AGE", "TAILLE-ENT", "ANCIENNETE",
    "QUOTITE-TRAV", "PRIX", "UNITE", "CORRECTION", "TYPE-SURF-ALIM", "MONNAIE", "DEVISE", "REVENU", "MIN-FPE",
    "EXPAGRI", "CHEPTEL", "FEDERATION", "MARCHE", "UNIT_MULT", "BASE_PER", "CONSOMMATION_ALCOOL_RISQUE",
    "MODE_CONTAMINATION_VIH", "RENONCEMENT_SOINS", "STATUT_ACTIVITE", "TYPE_ROUTE", "GRANDS_USAGES_EAU", "QUALITE_EAU",
    "PRODUIT_PHYTOSANITAIRE", "RACE_LOCALE_CLASSEE", "MASSE_CORPORELLE", "NIVEAU-VIE-MEDIAN", "UNITE-CONSOMMATION",
    "CONNECTION_INTERNET", "CREDITS_PUBLICS_RD", "EMISSION_GES", "SESC", "DISCIPLINE", "NIV_COMP_NUM", "PROJ_EDUC_DD",
    "ENCADREMENT", "EMPREINTE-CARBONE", "EVENEMENTS-RISQUES-NATURELS", "CONFIANCE-INSTITUTIONS", "JUSTICE", "SECTEURS",
    "TYPE_MAT_PREM", "SOLS_ART", "TYPE_TRAITEMENT_DECH_MEN", "DECHETS-CONSO-MENAGES", "OCEANS-MERS-COURS-EAU",
    "REGIONS_ECO", "ETAT_CONSERV_HAB_NAT", "HAB_NAT", "REGION_BIOGEO", "POSTES_CORINE",
    "ETAT_TYPE-POLLUTION_IMPACTS_SITE", "AIRES_TERRESTRES_PROTEGEES", "ESPECES_EXOTIQUES", "POP_OISEAUX_COMMUNS",
    "AIDES-DEVELOPPEMENT", "REDRESSEMENT_TOUR", "SECTEUR_LOCATIF", "CMA_PM10", "STATIONS_MESURE", "EAU", "ASSAINISSEMENT",
    "ENERGIE_PRIMAIRE", "SUPPRESSION"];

    auto r = left.leftouterjoin!(x => x, x => x)(right);
    assert(!r.empty);
    assert(!r.front.right.isNull);
}

unittest
{
    auto left = [1, 2, 3];
    auto right = [2, 4];

    auto r = left.leftouterjoin!(x => x, x => x)(right);
    auto rs = r.save;

    r.popFront();
    assert(r.front.left == 2);
    assert(rs.front.left == 1);
}

auto innerjoin(alias leftKeyFunc, alias rightKeyFunc, R1, R2)(R1 left, R2 right)
if(isInputRange!R1 && isInputRange!R2)
{
    import std.algorithm : filter, map;
    return left.leftouterjoin!(leftKeyFunc, rightKeyFunc)(right)
        .filter!(t => !t.right.isNull)
        .map!(t => Tuple!(ElementType!R1, "left", ElementType!R2, "right")(t.left, t.right.get));
}

unittest
{
    import std.algorithm : equal;
    import std.typecons : tuple;
    auto left = [2, 1, 2];
    auto right = [1, 3, 2];
    auto r = left.innerjoin!(x => x, x => x)(right);
    assert(!r.empty);
    assert(equal(r, [tuple(1, 1), tuple(2, 2), tuple(2, 2)]));
}

auto sort(alias less = "a < b", R)(R range)
if(isRandomAccessRange!R && hasLength!R)
{
    import std.functional : binaryFun;
    import std.algorithm : swap;
    alias lessFun = binaryFun!less;
    static assert(is(typeof(lessFun(range.front, range.front)) == bool), "less predicate must return a bool");

    foreach_reverse(n; 0 .. range.length)
    {
        bool swapped;

        foreach (i; 0 .. n)
        {
            if(!lessFun(range[i], range[i + 1]))
            {
                swap(range[i], range[i + 1]);
                swapped = true;
            }
        }
        if(!swapped) break;
    }
    return range;
}

unittest
{
    import std.algorithm : equal;
    auto i = [3, 7, 2];

    assert(i.sort.equal([2, 3, 7]));
}

auto dropDuplicates(alias less = "a < b", alias eq = "a == b", R)(R range)
if(isInputRange!R)
{
    import std.algorithm : uniq;
    static if(isRandomAccessRange!R)
    {
        return sort!less(range).uniq!eq;
    }
    else
    {
        import std.array : array;
        return range.array.sort!less.uniq!eq;
    }
}

unittest
{
    import std.algorithm : equal;
    auto i = [1, 2, 1, 1, 2, 3];
    assert(equal(dropDuplicates(i), [1, 2, 3]));
}

auto groupby(alias indexFunc, R)(R range)
{
    import std.typecons : tuple, Tuple;
    import std.algorithm : map, fold, sort;

    alias mapper = e => tuple(indexFunc(e), e);
    alias reducer = (acc, cur) {
        auto k = cur[0];
        auto v = cur[1];

        if(acc.length == 0) return [tuple(k, [v])];

        auto pk = acc[$ - 1][0];
        auto pv = acc[$ - 1][1];

        if(pk != k) return acc[0 .. $] ~ tuple(k, [v]);

        return acc[0 .. ($ - 1)] ~ tuple(k, pv ~ v);
    };

    alias KT = typeof(indexFunc(range.front));
    alias VT = ElementType!R;

    Tuple!(KT, VT[])[] seed;

    static if(isRandomAccessRange!R)
    {
        return range
            .sort!((a, b) => indexFunc(a) < indexFunc(b))
            .map!mapper
            .fold!reducer(seed);
    }
    else {
        import std.array : array;
        return range
            .array
            .sort!((a, b) => indexFunc(a) < indexFunc(b))
            .map!mapper
            .fold!reducer(seed);
    }
}

unittest
{
    import std.array : assocArray;
    import std.algorithm : equal;
    auto r = [Foo(0), Foo(1), Foo(0), Foo(3)].groupby!(i => i.id).assocArray;
    assert(equal(r[0], [Foo(0), Foo(0)]));
    assert(equal(r[1], [Foo(1)]));
    assert(equal(r[3], [Foo(3)]));
}

unittest
{
    Foo[] foos = [];
    auto r = foos.groupby!(i => i.id);
    assert(r.empty);
}

auto index(alias indexFunc, R)(R range)
{
    import std.typecons : tuple;
    import std.algorithm : map;

    return range.map!(e => tuple(indexFunc(e), e));
}

unittest
{
    import std.array : assocArray;
    import std.algorithm : equal;
    auto r = [Foo(0), Foo(1), Foo(0), Foo(3)].index!(i => i.id).assocArray;
    assert(r[0] == Foo(0));
    assert(r[1] == Foo(1));
    assert(r[3] == Foo(3));
}