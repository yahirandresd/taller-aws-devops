package edu.ucaldas.devops.repository;
import edu.ucaldas.devops.model.LandslideReport;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;
public interface LandslideRepository extends JpaRepository<LandslideReport, Long> {
    List<LandslideReport> findByRecordDateOrderByRecordTimeDesc(LocalDate recordDate);
}
