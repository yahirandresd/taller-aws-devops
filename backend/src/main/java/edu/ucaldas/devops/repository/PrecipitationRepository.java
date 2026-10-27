package edu.ucaldas.devops.repository;
import edu.ucaldas.devops.model.PrecipitationRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.LocalDate;
import java.util.List;
public interface PrecipitationRepository extends JpaRepository<PrecipitationRecord, Long> {
    List<PrecipitationRecord> findByRecordDateOrderBySectorAsc(LocalDate recordDate);
}
