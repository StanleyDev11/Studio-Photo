package com.studiophoto.photoappbackend.config;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;

@Component
@RequiredArgsConstructor
public class DimensionDataInitializer implements CommandLineRunner {

    private final DimensionRepository dimensionRepository;

    @Override
    public void run(String... args) throws Exception {
        if (dimensionRepository.count() == 0) {
            List<Dimension> dimensions = List.of(
                Dimension.builder().name("9x13 cm").price(new BigDecimal("75")).images("assets/carousel/car.jpg,assets/carousel/car1.jpg").title("Petit Format Classique").description("Idéal pour les albums photos ou les petits cadres. Un souvenir intime et abordable.").isPopular(false).build(),
                Dimension.builder().name("10x15 cm").price(new BigDecimal("150")).images("assets/carousel/car1.jpg,assets/carousel/mxx.jpeg,assets/carousel/pflex.jpeg").title("Format Standard").description("Le format le plus courant pour partager vos moments. Parfait pour les tirages du quotidien.").isPopular(true).build(),
                Dimension.builder().name("13x18 cm").price(new BigDecimal("125")).images("assets/carousel/mxx.jpeg,assets/carousel/pflex.jpeg").title("Portrait Élégant").description("Un choix populaire pour les portraits et les photos de famille. Offre une belle présence.").isPopular(true).build(),
                Dimension.builder().name("15x21 cm").price(new BigDecimal("175")).images("assets/carousel/pflex.jpeg,assets/carousel/Pink Modern Pink October Instagram Post .png").title("Polyvalent et Pratique").description("Excellent pour la plupart des photos, offre un bon équilibre entre taille et détail.").isPopular(false).build(),
                Dimension.builder().name("20x25 cm").price(new BigDecimal("375")).images("assets/carousel/Pink Modern Pink October Instagram Post .png,assets/carousel/Ajouter un sous-titre.png").title("Agrandissement Modéré").description("Mettez en valeur vos clichés préférés. Idéal pour les petits cadres muraux.").isPopular(true).build(),
                Dimension.builder().name("20x30 cm").price(new BigDecimal("500")).images("assets/carousel/Ajouter un sous-titre.png,assets/images/pro.png,assets/logos/mixbyyass.jpg").title("Format A4 Photo").description("Le format classique pour une reproduction fidèle. Idéal pour les présentations ou cadres.").isPopular(false).build(),
                Dimension.builder().name("24x30 cm").price(new BigDecimal("750")).images("assets/images/pro.png,assets/logos/mixbyyass.jpg").title("Grand Format Équilibré").description("Une taille imposante sans être démesurée. Pour un impact visuel certain.").isPopular(false).build(),
                Dimension.builder().name("30x40 cm").price(new BigDecimal("1250")).images("assets/logos/mixbyyass.jpg,assets/carousel/car.jpg,assets/carousel/car1.jpg").title("Galerie d'Art").description("Transformez vos photos en œuvres d'art. Un choix audacieux et expressif.").isPopular(true).build(),
                Dimension.builder().name("30x45 cm").price(new BigDecimal("1500")).images("assets/carousel/car.jpg,assets/carousel/car1.jpg").title("Panorama Standard").description("Parfait pour les paysages ou les photos de groupe. Un champ de vision étendu.").isPopular(false).build(),
                Dimension.builder().name("30x90 cm").price(new BigDecimal("2000")).images("assets/carousel/car1.jpg,assets/carousel/mxx.jpeg").title("Bandeau Panoramique").description("Pour des vues panoramiques spectaculaires. Créez un point focal unique.").isPopular(false).build(),
                Dimension.builder().name("40x50 cm").price(new BigDecimal("2500")).images("assets/carousel/mxx.jpeg,assets/carousel/pflex.jpeg").title("Affichage Mural").description("Impression grand format pour décorer un mur. Une présence forte et élégante.").isPopular(false).build(),
                Dimension.builder().name("40x60 cm").price(new BigDecimal("3250")).images("assets/carousel/pflex.jpeg,assets/carousel/Pink Modern Pink October Instagram Post .png").title("Impact Visuel Fort").description("Le choix des professionnels pour les expositions. Une clarté et un détail exceptionnels.").isPopular(false).build(),
                Dimension.builder().name("50x60 cm").price(new BigDecimal("3750")).images("assets/carousel/Pink Modern Pink October Instagram Post .png,assets/carousel/Ajouter un sous-titre.png").title("Très Grand Format").description("Pour immortaliser vos plus beaux souvenirs avec grandeur. Effet \"wow\" garanti.").isPopular(false).build(),
                Dimension.builder().name("60x90 cm").price(new BigDecimal("4500")).images("assets/carousel/Ajouter un sous-titre.png,assets/images/pro.png").title("Poster Géant").description("La taille idéale pour les posters ou les affiches promotionnelles. Attire tous les regards.").isPopular(false).build(),
                Dimension.builder().name("60x120 cm").price(new BigDecimal("6250")).images("assets/images/pro.png,assets/logos/mixbyyass.jpg").title("Immersion Maximale").description("La plus grande taille disponible pour une immersion totale. Une déclaration artistique.").isPopular(false).build()
            );
            dimensionRepository.saveAll(dimensions);
            System.out.println("Initialized " + dimensions.size() + " dimensions.");
        }
    }
}
