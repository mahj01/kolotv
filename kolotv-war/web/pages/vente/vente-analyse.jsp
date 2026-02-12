<%--
    Document   : as-commande-analyse
    Created on : 30 d�c. 2016, 04:57:15
    Author     : Joe
--%>
<%@page import="vente.VenteDetailsLib"%>
<%@page import="utilitaire.*"%>
<%@page import="affichage.*"%>
<%@page import="java.util.Calendar"%>
<%@ page import="support.Support" %>
<%@ page import="produits.CategorieIngredient" %>

<%
try{
    VenteDetailsLib mvt = new VenteDetailsLib();
    String nomTable = "VENTE_DETAILS_CPL_MOIS_VISEE";
    mvt.setNomTable(nomTable);

    String listeCrt[] = {"idProduitLib","daty","idSupport","idCategorie"};
    String listeInt[] = {"daty"};
    String[] pourcentage = {};
    String[] colGr = {"idProduitLib"};
    String[] colGrCol = {"mois"};
    //String somDefaut[] = {"qte", "puTotal", "puRevient"};
    String somDefaut[] = {"qte", "puTotal"};

    PageRechercheGroupe pr = new PageRechercheGroupe(mvt, request, listeCrt, listeInt, 3, colGr, somDefaut, pourcentage, colGr.length , somDefaut.length);
    pr.setUtilisateur((user.UserEJB) session.getValue("u"));
    pr.setLien((String) session.getValue("lien"));
    String apreswhere = "";
    String debutSem=Utilitaire.formatterDaty(Utilitaire.getDebutSemaine(Utilitaire.dateDuJourSql())) ;
    Calendar calendar = Calendar.getInstance();
    int month = calendar.get(Calendar.MONTH) + 1; // January is 0
    int year = calendar.get(Calendar.YEAR);
    String dateDebut = String.format("01/%02d/%04d", month, year);
    String dateFin = Utilitaire.dateDuJour();

    if(request.getParameter("daty1")==null&&request.getParameter("daty2")==null)
    apreswhere= "and daty >= TO_DATE('"+dateDebut+"','DD/MM/YYYY') and daty <= TO_DATE('"+dateFin+"','DD/MM/YYYY')";

    String order = "";
    if(request.getParameter("order")!=null && request.getParameter("order").compareToIgnoreCase("")!=0){
        order+= (" "+ request.getParameter("order"));
    }
    String[] grouper = new String[1];
    if(request.getParameter("grouper")!=null && request.getParameter("grouper").compareToIgnoreCase("")!=0){
        grouper[0]=request.getParameter("grouper");
        pr.setColGroupeDefaut(grouper);
    }
    pr.setOrdre(order);
    pr.setAWhere(apreswhere);
    Liste [] listes = new Liste[2];
    Support support = new Support();
    listes[0] = new Liste("idSupport",support,"val","id");
    CategorieIngredient cat = new CategorieIngredient();
    listes[1] = new Liste("idCategorie",cat,"val","id");
    pr.getFormu().changerEnChamp(listes);
    pr.getFormu().getChamp("daty1").setDefaut(dateDebut);
    pr.getFormu().getChamp("daty2").setDefaut(dateFin);
    pr.getFormu().getChamp("daty1").setLibelle("Date Min");
    pr.getFormu().getChamp("daty2").setLibelle("Date max");
    pr.getFormu().getChamp("idCategorie").setLibelle("Type de service");
    pr.getFormu().getChamp("idSupport").setLibelle("Support");
    pr.getFormu().getChamp("idProduitLib").setLibelle("Nom de service");
    pr.getFormu().getChamp("idProduitLib").setVisible(false);

    pr.setNpp(500);
    pr.setApres("vente/vente-analyse.jsp");
    pr.creerObjetPageCroise(colGrCol,pr.getLien()+"?but=");
%>
<script>
    function changerDesignation() {
        document.analyse.submit();
    }
    $(document).ready(function() {
        $('.box table tr').each(function() {
            $(this).find('td:last, th:last').hide();
        });

        // Calcule les totaux et les affiche dans un footer + ajoute une colonne "Total année".
        // Tout se fait côté client (JavaScript uniquement).
        buildVenteAnalyseTotals();
    });

    function alignTableCells() {
        const tbody = document.querySelector('tbody');
        if (!tbody) return;

        const rows = tbody.querySelectorAll('tr');

        rows.forEach((row) => {
            const cells = row.querySelectorAll('td');
            if (cells.length > 0) {
                cells[0].style.textAlign = 'center';
                cells[0].style.verticalAlign = 'middle';
            }
            if (cells.length > 1) {
                cells[1].style.textAlign = 'right';
            }
        });
    }
    document.addEventListener('DOMContentLoaded', alignTableCells);

    function isElementVisible(el) {
        if (!el) return false;
        // offsetParent est null si display:none
        if (el.offsetParent === null) return false;
        const cs = window.getComputedStyle(el);
        return cs.display !== 'none' && cs.visibility !== 'hidden';
    }

    function parseFrNumber(text) {
        if (text == null) return 0;
        let t = String(text)
            .replace(/\u00A0/g, ' ') // nbsp
            .replace(/\s+/g, ' ')
            .trim();
        if (t === '' || t === '-' ) return 0;

        // (1 234,56) => -1234.56
        let neg = false;
        if (/^\(.*\)$/.test(t)) {
            neg = true;
            t = t.substring(1, t.length - 1).trim();
        }

        // retirer séparateurs de milliers (espaces)
        t = t.replace(/\s/g, '');
        // virgule décimale => point
        t = t.replace(/,/g, '.');

        const n = Number(t);
        if (Number.isNaN(n)) return 0;
        return neg ? -n : n;
    }

    function formatFrNumber(n, decimals) {
        return new Intl.NumberFormat('fr-FR', {
            minimumFractionDigits: decimals,
            maximumFractionDigits: decimals
        }).format(n);
    }

    function extractCellLines(td) {
        if (!td) return [];
        // On récupère le texte avec sa structure de lignes.
        // innerText garde les retours à la ligne sur <br>/block.
        const raw = (td.innerText || td.textContent || '').replace(/\r/g, '');
        const lines = raw
            .split('\n')
            .map(s => s.replace(/\u00A0/g, ' ').trim())
            .filter(s => s !== '');
        return lines;
    }

    function findBestHeaderRow(thead) {
        if (!thead) return null;
        const rows = Array.from(thead.querySelectorAll('tr'));
        if (rows.length === 0) return null;
        // En général, la dernière ligne porte les mois; sinon fallback.
        return rows[rows.length - 1];
    }

    function buildVenteAnalyseTotals() {
        const table = document.querySelector('.box table') || document.querySelector('table');
        if (!table) return;

        const thead = table.querySelector('thead');
        const tbody = table.querySelector('tbody');
        if (!thead || !tbody) return;

        const headerRow = findBestHeaderRow(thead);
        if (!headerRow) return;

        const ths = Array.from(headerRow.querySelectorAll('th'));
        // indices des colonnes "mois" visibles (ex: 02/2026)
        const monthCols = [];
        for (let i = 0; i < ths.length; i++) {
            const th = ths[i];
            if (!isElementVisible(th)) continue;
            const label = (th.innerText || th.textContent || '').trim();
            if (/^\d{2}\/\d{4}$/.test(label)) {
                monthCols.push({ label, index: i });
            }
        }
        if (monthCols.length === 0) return;

        // Déterminer où insérer la colonne: avant la dernière colonne cachée si elle existe.
        const allHeaderCells = Array.from(headerRow.querySelectorAll('th'));
        let insertIndex = allHeaderCells.length;
        // Si la dernière colonne est cachée (cas du script jQuery), on insère juste avant.
        for (let i = allHeaderCells.length - 1; i >= 0; i--) {
            const th = allHeaderCells[i];
            if (!isElementVisible(th)) {
                insertIndex = i;
            } else {
                break;
            }
        }

        // Ajout du TH "Total année" dans la ligne d'en-tête (et les autres lignes thead si besoin)
        const theadRows = Array.from(thead.querySelectorAll('tr'));
        theadRows.forEach((tr) => {
            const cells = Array.from(tr.children);
            if (cells.length === 0) return;
            // Ajoute un th vide sur les lignes qui ne sont pas celle des labels mois, pour garder l'alignement.
            const isMonthRow = tr === headerRow;
            const th = document.createElement('th');
            th.textContent = isMonthRow ? 'Total année' : '';
            // insérer avant la colonne cachée (si elle existe)
            if (insertIndex >= 0 && insertIndex <= cells.length) {
                tr.insertBefore(th, cells[insertIndex] || null);
            } else {
                tr.appendChild(th);
            }
        });

        const totalsByMonth = new Map();
        monthCols.forEach(c => totalsByMonth.set(c.label, { qte: 0, montant: 0 }));
        const grand = { qte: 0, montant: 0 };

        // Ajout cellule "Total année" par ligne
        const bodyRows = Array.from(tbody.querySelectorAll('tr'));
        bodyRows.forEach((tr) => {
            if (!isElementVisible(tr)) return;
            const tds = Array.from(tr.querySelectorAll('td'));
            if (tds.length === 0) return;

            let rowQte = 0;
            let rowMontant = 0;

            monthCols.forEach(({ label, index }) => {
                const td = tds[index];
                if (!td || !isElementVisible(td)) return;

                const lines = extractCellLines(td);
                // attendu: [qte, montant]
                const qte = lines.length >= 1 ? parseFrNumber(lines[0]) : 0;
                const montant = lines.length >= 2 ? parseFrNumber(lines[1]) : 0;

                const acc = totalsByMonth.get(label);
                acc.qte += qte;
                acc.montant += montant;

                rowQte += qte;
                rowMontant += montant;
            });

            grand.qte += rowQte;
            grand.montant += rowMontant;

            const tdTotal = document.createElement('td');
            tdTotal.style.textAlign = 'right';
            tdTotal.innerHTML =
                '<div>' + formatFrNumber(rowQte, 2) + '</div>' +
                '<div>' + formatFrNumber(rowMontant, 2) + '</div>';

            // insérer avant la colonne cachée (si elle existe)
            if (insertIndex >= 0 && insertIndex <= tds.length) {
                tr.insertBefore(tdTotal, tds[insertIndex] || null);
            } else {
                tr.appendChild(tdTotal);
            }
        });

        // Construire un tfoot à 2 lignes: qte puis montant
        const oldTfoot = table.querySelector('tfoot');
        if (oldTfoot) oldTfoot.remove();
        const tfoot = document.createElement('tfoot');

        const makeFooterRow = (label, isMontant) => {
            const tr = document.createElement('tr');
            tr.style.fontWeight = 'bold';

            const tdLabel = document.createElement('td');
            tdLabel.textContent = label;
            tdLabel.style.textAlign = 'left';
            tr.appendChild(tdLabel);

            // autres colonnes avant les mois => cellules vides (jusqu'à la première colonne mois)
            const firstMonthIndex = monthCols[0].index;
            for (let i = 1; i < firstMonthIndex; i++) {
                const td = document.createElement('td');
                td.textContent = '';
                tr.appendChild(td);
            }

            monthCols.forEach(({ label }) => {
                const acc = totalsByMonth.get(label);
                const td = document.createElement('td');
                td.style.textAlign = 'right';
                td.textContent = isMontant
                    ? formatFrNumber(acc.montant, 2)
                    : formatFrNumber(acc.qte, 2);
                tr.appendChild(td);
            });

            // Colonne Total année
            const tdYear = document.createElement('td');
            tdYear.style.textAlign = 'right';
            tdYear.textContent = isMontant
                ? formatFrNumber(grand.montant, 2)
                : formatFrNumber(grand.qte, 2);
            tr.appendChild(tdYear);

            // Si une colonne cachée existe en fin, garder l'alignement avec une dernière cellule vide
            const lastHeaderCells = Array.from(headerRow.querySelectorAll('th'));
            const hasHiddenTail = lastHeaderCells.length > 0 && !isElementVisible(lastHeaderCells[lastHeaderCells.length - 1]);
            if (hasHiddenTail) {
                const td = document.createElement('td');
                td.textContent = '';
                td.style.display = 'none';
                tr.appendChild(td);
            }

            return tr;
        };

        tfoot.appendChild(makeFooterRow('Total (Qté)', false));
        tfoot.appendChild(makeFooterRow('Total (Montant)', true));
        table.appendChild(tfoot);
    }
</script>
<div class="content-wrapper">
    <section class="content-header">
        <h1>Analyse de rentabilit&eacute; de service de diffusion</h1>
    </section>
    <section class="content">
        <form action="<%=pr.getLien()%>?but=vente/vente-analyse.jsp" method="post" name="analyse" id="analyse">
            <%out.println(pr.getFormu().getHtmlEnsemble());%>
        </form>
        <ul>
            <li>La premi&egrave;re ligne correspond &agrave; la quantit&eacute;</li>
            <li>La 2&egrave;me ligne correspond au montant total</li>
        </ul>
           <%
            String lienTableau[] = {};
            pr.getTableau().setLien(lienTableau);
            pr.getTableau().setColonneLien(somDefaut);%>
        <br>
        <%
            out.println(pr.getTableau().getHtml());
            out.println(pr.getBasPage());
        %>
    </section>
</div>
<%
    }catch(Exception e){
        e.printStackTrace();
    }
%>
