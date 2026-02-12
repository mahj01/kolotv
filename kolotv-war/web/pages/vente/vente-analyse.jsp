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
        // Attendre que le tableau soit rendu
        setTimeout(function() {
            var table = $('#selectnonee table').first();
            if (table.length === 0) {
                console.log('Table non trouvée');
                return;
            }
            
            console.log('Table trouvée:', table.length);
            
            // Masquer la dernière colonne (colonne vide générée par le framework)
            table.find('tbody tr').each(function() {
                $(this).find('td:last-child').hide();
            });
            
            // Ajouter les totaux
            ajouterColonneTotaux(table);
        }, 300);
    });
    
    function ajouterColonneTotaux(table) {
        var tbody = table.find('tbody');
        var allRows = tbody.find('tr');
        
        if (allRows.length < 2) {
            console.log('Pas assez de lignes');
            return;
        }
        
        // La première ligne contient les en-têtes (mois)
        var headerRow = allRows.first();
        // Les lignes de données (sauf la première qui est l'en-tête et la dernière qui est le total du framework)
        var dataRows = allRows.slice(1, allRows.length - 1);
        
        // Compter les colonnes visibles dans l'en-tête
        var headerCells = headerRow.find('td:visible');
        var nbColonnes = headerCells.length - 1; // -1 pour la colonne libellé
        
        console.log('Nombre de colonnes de données:', nbColonnes);
        
        if (nbColonnes <= 0) return;
        
        // Ajouter l'en-tête TOTAL dans la première ligne
        headerRow.append('<td style="text-align:center; font-weight:bold; background-color:#1976d2; color:white; padding:8px;">TOTAL</td>');
        
        // Variables pour les totaux par colonne
        var totauxColQte = [];
        var totauxColMontant = [];
        for (var i = 0; i < nbColonnes; i++) {
            totauxColQte[i] = 0;
            totauxColMontant[i] = 0;
        }
        
        var grandTotalQte = 0;
        var grandTotalMontant = 0;
        
        // Pour chaque ligne de données, calculer et ajouter le total
        dataRows.each(function() {
            var row = $(this);
            var cells = row.find('td:visible');
            
            if (cells.length <= 1) return true; // continue
            
            var totalQte = 0;
            var totalMontant = 0;
            var colIndex = 0;
            
            // Parcourir les cellules de données (skip la première = libellé)
            cells.each(function(index) {
                if (index === 0) return true; // Skip libellé
                
                var cellHtml = $(this).html();
                var parts = cellHtml.split(/<br\s*\/?>/i);
                
                if (parts.length >= 1) {
                    var qteText = $('<div>').html(parts[0]).text().trim();
                    var qte = parseFloat(qteText.replace(/\s/g, '').replace(',', '.')) || 0;
                    totalQte += qte;
                    if (colIndex < nbColonnes) {
                        totauxColQte[colIndex] += qte;
                    }
                }
                if (parts.length >= 2) {
                    var montantText = $('<div>').html(parts[1]).text().trim();
                    var montant = parseFloat(montantText.replace(/\s/g, '').replace(',', '.')) || 0;
                    totalMontant += montant;
                    if (colIndex < nbColonnes) {
                        totauxColMontant[colIndex] += montant;
                    }
                }
                colIndex++;
            });
            
            grandTotalQte += totalQte;
            grandTotalMontant += totalMontant;
            
            // Ajouter cellule TOTAL pour cette ligne
            row.append('<td style="text-align:right; font-weight:bold; background-color:#e3f2fd; border-left:3px solid #1976d2; padding:8px;">' + 
                formatNombre(totalQte) + '<br>' + formatNombre(totalMontant) + '</td>');
        });
        
        // Ajouter le total à la dernière ligne (ligne de totaux du framework)
        var lastRow = allRows.last();
        lastRow.append('<td style="text-align:right; font-weight:bold; background-color:#4caf50; color:white; border-left:3px solid #1976d2; padding:8px; font-size:1.1em;">' +
            formatNombre(grandTotalQte) + '<br>' + formatNombre(grandTotalMontant) + '</td>');
        
        // Styliser la dernière ligne
        lastRow.css({
            'font-weight': 'bold',
            'background-color': '#fff3e0',
            'border-top': '3px solid #e65100'
        });
        lastRow.find('td:first').css({
            'background-color': '#e65100',
            'color': 'white',
            'text-align': 'center'
        });
        
        console.log('Totaux ajoutés - Grand total Qte:', grandTotalQte, 'Montant:', grandTotalMontant);
    }
    
    function formatNombre(num) {
        if (num === undefined || num === null || isNaN(num)) {
            return '0,00';
        }
        // Formater avec séparateur de milliers et 2 décimales
        var parts = num.toFixed(2).split('.');
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
        return parts.join(',');
    }
    
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
